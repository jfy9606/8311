#!/bin/sh
#************************************************#
# vlanexec.sh                                    #
# VLAN Tagging Operation customisation engine    #
#************************************************#

# Script start
# exec variable
onu="/opt/lantiq/bin/onu"
uci="/sbin/uci"
omci="/opt/lantiq/bin/omci_pipe.sh"
omci_simulate="/opt/lantiq/bin/omci_simulate"
gtop="/opt/lantiq/bin/gtop"
optic="/opt/lantiq/bin/optic"

init_flag=0
totalizer_flag=0
collect_flag=0
state_flag=0
log_flag=0
reboot_delay_interval=0

reboots_count=$(cat /tmp/reboots_count 2>&-)

reboot_on_association_fail=$($uci -q get 8311.config.reboot_on_association_fail)
max_reboot_delay_intervals=$($uci -q get 8311.config.max_reboot_delay_intervals)
max_reboots=$($uci -q get 8311.config.max_reboots)
persist_log_on_reboot=$($uci -q get 8311.config.persist_log_on_reboot)

us_vlan_id=$($uci -q get 8311.config.us_vlan_id)
n_to_1_vlan=$($uci -q get 8311.config.n_to_1_vlan)
vlan_tag_ops=$($uci -q get 8311.config.vlan_tag_ops)
ds_mc_tci=$($uci -q get 8311.config.ds_mc_tci)
us_mc_vid=$($uci -q get 8311.config.us_mc_vid)
igmp_version=$($uci -q get 8311.config.igmp_version)
force_me_create=$($uci -q get 8311.config.force_me_create)
force_me309_create=$($uci -q get 8311.config.force_me309_create)
force_us_vlan_id=$($uci -q get 8311.config.force_us_vlan_id)
vlan_svc_log=$($uci -q get 8311.config.vlan_svc_log)

vid_pattern='4096|409[0-4]|(40[0-8]|[1-3][[:digit:]][[:digit:]]|[1-9][[:digit:]]|[1-9])[[:digit:]]|[0-9]'

get_ploam_state() {
	$onu ploam_state_get |
		cut -b 24
}

do_reboot() {
	if [ "$reboots_count" -lt "$max_reboots" ]; then
		if [ "$persist_log_on_reboot" = "1" ]; then
			/opt/lantiq/bin/debug
			cp /tmp/log/one_click /root
		fi

		reboots_count=$((reboots_count + 1))

		fw_setenv reboot_attempt "$reboots_count"
		fw_setenv rebootcause 1

		reboot -f
		exit 0
	fi
}

reset_reboot_attempt() {
	fw_setenv reboot_attempt 0
}

delay_reboot() {
	if [ "$reboot_delay_interval" -lt "$max_reboot_delay_intervals" ] &&
		[ "$reboots_count" -lt "$max_reboots" ]; then
		reboot_delay_interval=$((reboot_delay_interval + 1))
		rest
	fi
}

reset_reboot_delay() {
	reboot_delay_interval=0
}

reset_log_flag() {
	log_flag=0
}

check_onu_fsm_o5() {
	local prev_status
	local curr_status

	if [ ! -f /tmp/oltstatus1 ]; then
		touch /tmp/oltstatus1
	fi

	prev_status=$(cat /tmp/oltstatus1)
	curr_status=$(dmesg | grep -c "FSM O5")

	if [ "$prev_status" != "$curr_status" ]; then
		logger -t "[vlanexec]" "FSM O5 detected..."
		totalizer_flag=$((totalizer_flag + 1))
	fi

	echo "$curr_status" >/tmp/oltstatus1
}

check_onu_rx_msg_lost() {
	local prev_status
	local curr_status

	if [ ! -f /tmp/oltstatus2 ]; then
		touch /tmp/oltstatus2
	fi

	prev_status=$(cat /tmp/oltstatus2)
	curr_status=$(dmesg | grep -c "PLOAM Rx - message lost")

	if [ "$prev_status" != "$curr_status" ]; then
		logger -t "[vlanexec]" "PLOAM Rx - message lost detected..."
		totalizer_flag=$((totalizer_flag + 1))
	fi

	echo "$curr_status" >/tmp/oltstatus2
}

rest() {
	local time

	if [ $state_flag -lt 20 ]; then
		time=5
	else
		time=15
	fi
	sleep $time
}

reset_tracked_parameters() {
	local vlans_seq
	local vlan_a_seq
	local vlan_b_seq
	local vlan_tagging_ops_num

	init_flag=0
	totalizer_flag=0
	state_flag=0

	[ -e /tmp/us_vlan_data ] && rm -f /tmp/us_vlan_data
	[ -e /tmp/ds_mc_tci_data ] && rm -f /tmp/ds_mc_tci_data
	[ -e /tmp/us_mc_vid_data ] && rm -f /tmp/us_mc_vid_data
	[ -e /tmp/mibcounter ] && rm -f /tmp/mibcounter

	vlans_seq=0
	vlan_tagging_ops_num=$(
		echo "$vlan_tag_ops" |
			grep -o ":" |
			grep -c ":"
	)

	for i in $(seq 1 "$vlan_tagging_ops_num"); do
		vlan_a_seq=$((i + vlans_seq))

		vlans_seq=$i

		vlan_b_seq=$((i + vlans_seq))

		if [ -e "/tmp/vlan$vlan_a_seq" ] || [ -e "/tmp/vlan$vlan_b_seq" ]; then
			rm -f /tmp/vlan$vlan_a_seq
			rm -f /tmp/vlan$vlan_b_seq
		fi
	done
}

collect_olt_type() {
	local spanning_tree

	for i in $(seq 1 30); do
		olt_type=$(
			$omci managed_entity_attr_data_get 131 0 1 |
				sed -n 's/\(attr\_data\=\)/\1/p' |
				cut -f 3 -d '=' |
				sed s/[[:space:]]//g
		)

		spanning_tree=$(
			$omci managed_entity_attr_data_get 45 1 1 |
				sed -n 's/\(attr\_data\=\)/\1/p' |
				sed s/[[:space:]]//g
		)

		if [ "$olt_type" != "20202020" ] && [ -n "$spanning_tree" ]; then
			break
		else
			logger -t "[vlanexec]" "OLT type and spanning tree not detected, waiting..."
			sleep 2
		fi
	done

	echo "OLT type: $olt_type" >/tmp/collect
}

collect_extended_vlan() {
	local me171_associated_me_ptr
	local me171_instances
	local me171_instance_count

	me171_instances=$(
		$omci mib_dump |
			grep "Extended VLAN conf data" |
			sed -n 's/\(0x\)/\1/p' |
			cut -f 3 -d '|' |
			cut -f 1 -d '(' |
			head -n 1 |
			sed s/[[:space:]]//g
	)

	me171_instance_count=$(
		$omci mib_dump |
			grep -c "Extended VLAN conf data"
	)

	if [ "$me171_instance_count" -gt 1 ]; then
		for i in $me171_instances; do
			me171_associated_me_ptr=$(
				$omci managed_entity_attr_data_get 171 "$i" 7 |
					sed -n 's/\(attr\_data\=\)/\1/p' |
					sed s/[[:space:]]//g
			)

			if [ "$me171_associated_me_ptr" = "0101" ]; then
				me171_instance_id=$i
				if [ -n "$vlan_svc_log" ]; then
					logger -t "[vlan]" "ME 171 exists with instance id: $me171_instance_id"
				fi
				break
			fi
		done
	else
		me171_instance_id=$me171_instances
	fi

	if [ -z "$me171_instance_id" ]; then
		echo "ME 171 instance id is null." >>/tmp/collect
	else
		echo "ME 171 instance id: $me171_instance_id" >>/tmp/collect
	fi
}

# Main process loop
while true; do
	# Check ONU state
	ploam_state=$(get_ploam_state)
	
	if [ "$ploam_state" != "5" ]; then
		if [ -n "$vlan_svc_log" ]; then
			logger -t "[vlanexec]" "ONU not in operation state. Current state: $ploam_state"
		fi
		sleep 5
		continue
	fi

	if [ "$init_flag" -eq 0 ]; then
		logger -t "[vlanexec]" "Initializing VLAN service..."
		reset_tracked_parameters
		collect_olt_type
		collect_extended_vlan
		init_flag=1
	fi

	# Apply VLAN configurations
	if [ -n "$us_vlan_id" ] && [ -n "$n_to_1_vlan" ] && [ -n "$vlan_tag_ops" ]; then
		# Configure extended VLAN tagging
		$omci managed_entity_attr_data_set 171 "$me171_instance_id" 1 "0x8100"
		$omci managed_entity_attr_data_set 171 "$me171_instance_id" 2 "0x8100"
		
		# Configure multicast VLAN if needed
		if [ -n "$ds_mc_tci" ] && [ -n "$us_mc_vid" ]; then
			logger -t "[vlanexec]" "Configuring multicast VLAN: DS=$ds_mc_tci, US=$us_mc_vid"
			$omci managed_entity_attr_data_set 130 1 1 "$ds_mc_tci$us_mc_vid"
		fi
		
		logger -t "[vlanexec]" "VLAN configuration applied successfully"
	else
		logger -t "[vlanexec]" "Missing VLAN configuration parameters"
	fi

	# Monitor for changes in ONU state
	check_onu_fsm_o5
	check_onu_rx_msg_lost

	# If ONU state changes, reset and reconfigure
	if [ "$totalizer_flag" -gt 5 ]; then
		logger -t "[vlanexec]" "ONU state changed, reconfiguring VLAN settings"
		reset_tracked_parameters
	fi
	
	sleep 30
done 
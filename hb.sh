#!/bin/bash

# address of FT pair
export cache1="raicache01:38080"
export cache2="raicache02:38080"
# rv service that has _TIC.RSF.> broadcast feed
export feed_network="-service 3333"
# rv service that hs RSF.> subscription
export sub_network="-service 4444"
# rv service to publish HB subjects
export status_network="-service 7500"
# hb generator
export pingrv=/usr/rai/bin/pingrv2
# hb monitor
export subrv=/usr/rai/bin/subrvtest2
# get and modify raicache state
export cacheadmin=/usr/rai/bin/cacheadmin
# status/event generator for hb subjects
export pubrv=/usr/rai/bin/raipub2
# hbs are published and subscribed, pub auto adds _TIC. prefix
export heartbeat_subject=RSF.REC.PING.NaE
# status are publish here
export status_subject=HB.REC.STATUS.NaE
# events are publish here
export event_subject=HB.REC.EVENT.NaE
# the timeout for heartbeats
export interval=10
# this current timeout, incremented by 10 after hb failure
export current_ival=10
# current count of heartbeats received
export hb_count=0
export hname=$(hostname)

start_heartbeat_ping() {
  # publish a heartbeaat 
  exec 3< <($pingrv $feed_network -perSec 1 -noSub -subject $heartbeat_subject > /dev/null 2>&1)
}

start_heartbeat_subrv() {
  # subscribe the heartbeat
  exec 4< <($subrv $sub_network -subject $heartbeat_subject -noDict 2>&1)
}

publish() {
  # publish a status/event
  local subject=$1
  local field=$2
  local message=$3
  $pubrv $status_network -prefix "" -rv -nohdr -subject $subject -data "${field}:s=${message}" > /dev/null 2>&1
}

start_heartbeat() {
  pkill -P $$

  start_heartbeat_ping
  start_heartbeat_subrv
}
start_heartbeat

# kill hbs on exit
trap 'pkill -P $$' EXIT

pub_status() {
  local now=$(date)
  publish $status_subject status "$now -- $*"
}

pub_event() {
  local now=$(date)
  publish $event_subject event "$now -- $*"
}

is_primary() {
  local address=$1
  [[ $($cacheadmin -a $address -get state 2> /dev/null) == *Primary* ]]
}

is_secondary() {
  local address=$1
  [[ $($cacheadmin -a $address -get state 2> /dev/null) == *Secondary* ]]
}

activate() {
  local address=$1
  pub_event "activate $address"
  $cacheadmin -a $address -get activate
}

check_state() {
  local cache=$1
  if is_primary $cache ; then
    pub_event "$cache is primary from $hname"
  elif is_secondary $cache ; then
    pub_event "$cache is secondary from $hname"
  else
    pub_event "$cache is missing from $hname"
  fi
}
check_state $cache1
check_state $cache2

read_with_timeout() {
  local line
# time format seconds
  local start=$(date +%s)

  if IFS= read -r -t $current_ival line <&4 ; then
# match hb subject
    if [[ $line == *${heartbeat_subject}* ]] ; then
      hb_count=$(($hb_count + 1))
      current_ival=$interval
      if [ $(( $hb_count % 10 )) -eq 0 ] ; then
        pub_status "Heartbeat count $hb_count from $hname"
      fi
    fi
  else
    local end=$(date +%s)
# if pipe to subrv closed, will read empty line immediately
    if [ $(( $start + $current_ival - 1 )) -ge $end ] ; then
      pub_event "Heartbeats died from $hname"
      start_heartbeat
    else
# read time expired $current_ival
      pub_event "Heartbeat timeout interval $current_ival from $hname"
      current_ival=$(($current_ival + 10))
      if is_primary $cache1 ; then
        activate $cache2
      elif is_primary $cache2 ; then
        activate $cache1
      fi
    fi
  fi
}

while true ; do
  read_with_timeout
done

exec 3<&-
exec 4<&-


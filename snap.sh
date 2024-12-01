#!/bin/bash

# rv service that has _TIC.RSF.> broadcast feed
export feed_network="-service 3333"
# rv service that hs RSF.> subscription
export sub_network="-service 4444"
# rv service to publish HB subjects
export status_network="-service 7500"
# snap/status/event generator
export pubrv=/usr/rai/bin/raipub2
# snap monitor
export subrv=/usr/rai/bin/subrvtest2
# subject to snap
export snap_subject=
# status are publish here
export status_subject=SNAP.REC.STATUS.NaE
# events are publish here
export event_subject=SNAP.REC.EVENT.NaE
# the timeout for snapshots
export interval=10
# current count of snapshots received
export snap_count=0
# current count of snaps published
export snap_seqno=0

export hname=$(hostname)
make_snap_subject() {
  snap_subject=RSF.REC.SNAP$(($snap_seqno % 100)).$hname
}

snap_record() {
  pkill -P $$

  make_snap_subject
  snap_seqno=$(($snap_seqno + 1))

  # publish a record
  $pubrv -nohdr $feed_network -rv -subject $snap_subject -prefix "_TIC." -data 'MSG_TYPE:u16=8,REC_STATUS:u16=0,SNAP_SENT:u32=${snap_seqno},SNAP_RECV:u32=${snap_count}' > /dev/null 2>&1

  # subscribe the record
  exec 4< <($subrv $sub_network -snap -subject $snap_subject -noDict 2>&1)
}

# kill hbs on exit
trap 'pkill -P $$' EXIT

publish() {
  # publish a status/event
  local subject=$1
  local field=$2
  local message=$3
  $pubrv $status_network -prefix "" -rv -nohdr -subject $subject -data "${field}:s=${message}" > /dev/null 2>&1
}

pub_status() {
  local now=$(date)
  publish $status_subject status "$now -- $*"
}

pub_event() {
  local now=$(date)
  publish $event_subject event "$now -- $*"
}


read_with_timeout() {
  local line

  snap_record
  while true ; do
    if IFS= read -r -t $interval line <&4 ; then
      if [[ $line == *${snap_subject}* ]] ; then
        snap_count=$(($snap_count + 1))
        if [ $(( $snap_count % 10 )) -eq 0 ] ; then
          pub_status "Snap count $snap_count from $hname"
        fi
        exec 4<&-
        return 0
      fi
    else
      pub_event "Snap timeout interval $interval from $hname"
      exec 4<&-
      return 1
    fi
  done
}

while true ; do
  read_with_timeout
  sleep 1
done

exec 4<&-


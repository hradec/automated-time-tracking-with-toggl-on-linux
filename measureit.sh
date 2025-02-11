#!/bin/bash

ignored="$HOME/.measureit.ignore"
projects="$HOME/.measureit.projects"
notbillable="$HOME/.measureit.notbillable"

if [ ! -f "$ignored" ]; then
  echo -n > $ignored
fi

if [ ! -f "$projects" ]; then
  echo -n > $projects
fi

if [ ! -f "$notbillable" ]; then
  echo -n > $notbillable
fi


function make_entry() {

  if [ -n "$5" ]; then
    project_id="$5"
    ep="assigned to project $project_id"
  else
    project_id=""
    ep="not assigned"
  fi

  if [ -n "$6" ]; then
    billable="false"
    eb="Not billable entry:"
  else
    billable="true"
    eb="Billable entry:"
  fi

  if [ -n "$project_id" ]; then
     json="{\"time_entry\":{\"description\":\"$1\",\"created_with\":\"measureit\",\"start\":\"$2\",\"duration\":$3,\"billable\":$billable,\"pid\":$project_id}}"
  else 
     json="{\"time_entry\":{\"description\":\"$1\",\"created_with\":\"measureit\",\"start\":\"$2\",\"duration\":$3,\"billable\":$billable}}"
  fi

  curl -v -u $4:api_token \
    -H "Content-Type: application/json" \
    -d "$json" \
    -X POST https://www.toggl.com/api/v8/time_entries 2>/dev/null >/dev/null
  echo "$eb $1 $2 $3 sec $ep"
}

function import_projects() {
  curl -u "$1:api_token" -X GET "https://www.toggl.com/api/v8/me?with_related_data=true" 2>/dev/null|jq '.data.projects'|grep -e \"id -e \"name|while read l
 do
  v=`echo $l|cut -d":" -f2|cut -d, -f1|cut -d" " -f2`;
  id=$v;
  read l;
  v=`echo $l|cut -d":" -f2|cut -d, -f1|cut -d"\"" -f2`;
  name=$v;
  p=`cat $projects|grep "$name"`;
  if [ -z "$p" ]; then
   echo "$id;$name" >> $projects
  fi
done
 
 
}

if [ -z "$2" ]; then
  echo "Usage: <toggl user name> <toggl password> [minimal interval] [step]"
  exit
fi

TUSER=$1
TPASS=$2
INTERVAL=$3
STEP=$4
if [ -z "$INTERVAL" ]; then
  INTERVAL=300
fi
if [ -z "$STEP" ]; then
  STEP=1
fi

n=0
wold=""
told=$(date +"%Y-%m-%dT%H:%M:%S+01:00")

api_token=$(curl -u $TUSER:$TPASS -X GET https://www.toggl.com/api/v8/me 2>/dev/null | jq -r ".data.api_token");
import_projects $api_token;

while sleep $STEP; do
  w=$(xdotool getactivewindow getwindowname 2> /dev/null|tr '[:upper:]' '[:lower:]'|iconv )
  t=$(date +"%Y-%m-%dT%H:%M:%S+01:00")
  if [ "$w" != "$wold" ] && [ -n "$w" ]; then
    ig=$(cat $ignored | grep -ve "^$" | while read i; do
      if [ -n "$(echo -n "$wold" | grep "$i")" ]; then
        echo "yes";
      fi
    done);
    project_id=$(cat $projects | grep -ve "^$" | while read i; do
      pid=$(echo $i | cut -d";" -f1)
      q=$(echo $i | cut -d";" -f2)
      if [ -n "$(echo -n "$wold" | grep -i "$q")" ]; then
        echo "$pid";
      fi
    done);
    notbill=$(cat $notbillable | grep -ve "^$" | while read i; do
      if [ -n "$(echo -n "$wold" | grep "$i")" ]; then
        echo "yes";
      fi
    done);
    if [ -z "$ig" ] && [ $n -gt $INTERVAL ]; then
      api_token=$(curl -u $TUSER:$TPASS -X GET https://www.toggl.com/api/v8/me 2>/dev/null | jq -r ".data.api_token")
      make_entry "$wold" "$told" "$n" "$api_token" "$project_id" "$notbill"
    fi
    n=0
    wold="$w"
    told="$t"
  fi
  n=$(expr $n + $STEP)
done

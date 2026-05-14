#!/bin/bash
# versions 1.0 amlepe
PARAM_NAME=$1
PARAM_NAME_2=$2

if [[ -z $PARAM_NAME_2 ]]; then
  rx_pat="^\s*$PARAM_NAME"
  PARAM_DISPLAY=$PARAM_NAME
else
  rx_pat="^\s*($PARAM_NAME|$PARAM_NAME_2)"
  PARAM_DISPLAY="$PARAM_NAME/$PARAM_NAME_2"
fi

level="local";

OS_NAME=`uname`;
if [[ "$OS_NAME" == "SunOS" ]] || [[ "$OS_NAME" =~ "HP" ]]
then

  PARAM_VALUE=`egrep -i "$rx_pat" $HOME/.ssh/config`
  cmd_st=$?

  if [ "$cmd_st" -ne 0 ]
  then
  
    level="ssh_config";
    PARAM_VALUE=`egrep -i "$rx_pat" /etc/ssh/ssh_config `
    cmd_st=$?
    if [ "$cmd_st" -ne 0 ]
    then
      echo "$PARAM_DISPLAY none";

    else
      echo "$PARAM_VALUE";
    fi
  else
    echo "$PARAM_VALUE";
  fi

else
  PARAM_VALUE=`ssh -G $HOSTNAME| egrep -i "$rx_pat" `
  cmd_st=$?
  if [ "$cmd_st" -ne 0 ]
  then
    echo "$PARAM_DISPLAY none";
  else
    echo "$PARAM_VALUE";
  fi
fi

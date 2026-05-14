#!/bin/bash

getPaddedFileVersion () {
fver=$1
segs=$(echo $fver | tr "\." "\n")

#printf "$segs\n"
point=".";

num_segs=0;
for seg in $segs
do
  #pseg=`printf "%012d" $seg`;
  pseg="$(printf \"%012d\" $seg)";
  ret=$ret$point$pseg;
  num_segs=$((num_segs + 1))
done

for (( ; num_segs < 8; num_segs++ ))
do
  ret=$ret$point"000000000000";
done

#printf "$ret\n";
#printf "num_segs: $num_segs\n";

echo "$ret";
}

fileVersionCmd () {
  cmd=$1;
  obj=$2;
  token=$3

  if [[ "$cmd" == "unzip" ]]; then
    ver="$(unzip -z $obj |awk '{print $3}'|tr -d '\n')"
  elif [[ "$cmd" == "adident" ]]; then
    if [[ "$token" != "Header" ]]; then
      ver="$(adident Header $obj | grep $token | awk '{print $3}'|tr -d '\n')";
    else
      ver="$(adident $token $obj |awk '{print $3}'|tr -d '\n')";
    fi
  fi

  echo "$ver";
}

compareEBSFVersions () {
ver1=$1
ver2=$2
op=$3

ret=0

ver1="$(getPaddedFileVersion $ver1)";
ver2="$(getPaddedFileVersion $ver2)";

if [[ "$op" == "lt" ]]; then
  if [[ "$ver1" < "$ver2" ]]; then
    ret=1;
  fi
elif [[ "$op" == "le" ]]; then
  if [[ $ver1 < $ver2 || $ver1 == $ver2 ]]; then
    ret=1;
  fi
elif [[ "$op" == "gt" ]]; then
  if [[ "$ver1" > "$ver2" ]]; then
    ret=1;
  fi
elif [[ "$op" == "ge" ]]; then
  if [[ $ver1 > $ver2 || $ver1 == $ver2 ]]; then
    ret=1;
  fi
elif [[ "$op" == "eq" ]]; then
  if [[ "$ver1" == "$ver2" ]]; then
    ret=1;
  fi
fi

echo "$ret";
}

cmd=$1
par1=$2
par2=$3
par3=$4

ret="$($cmd $par1 $par2 $par3)"
#printf "return: $ret\n";
printf "$ret";

#!/bin/bash

# Running without arguments will produce output like this. you can set $1 to one of those values to test a valid code.
# "$1" will be hashed with the server secret to create a hash to test with. The hash would otherwise be generated on the client.
#
# eg: ./hotp.sh 1670008229 ---------------+
#                                         |
# ...                                     |
# moving secs: 1670008224                 |
# moving secs: 1670008225                 |
# moving secs: 1670008226                 |
# moving secs: 1670008227                 |
# moving secs: 1670008228                 |
# moving secs: 1670008229 <---------------+
# moving secs: 1670008230
# range         : +/- 61
# user hash     : 4a6731c2eb3efecf1c86456ea23e155cb16537d2
# server hash   : 6043b3b2dda376e79ec226417862b562ae4631c3
# match         :
# 

# manifest errors produced by any pipe
set -o pipefail

# secret key - openssl rand -hex 20
secret="a69b8d50ba4f1a8bf12c1254d402664d4ec7bdae"

# cli only: enter current date in seconds as "$1" to test, or let script use the current time (for testing)
test -z "$1" && received_val="$(date '+%s')" || received_val="${1}"

# create hash of received seconds and secret mashed together - this would otherwise
# be done on client and sent over ether
u_hash=$(echo "${secret}${received_val}" | sha1sum | cut -d' ' -f1)

# wall clock differences between systems - include past 60 seconds.. or 120, or whatever
LIMIT="60";

# entries older than reap_hours are removed from the OTP hash
reap_hours="1"

# track recieved values so they are only allowed to be used once
output="hashe-cache.txt"

# see if user hash already exists in hashe-cache
grep "${u_hash}" "${output}" && { echo "OTP already used."; exit 1; }

# start at -$LIMIT and iterate up to $LIMIT
emc="$(($LIMIT * -1))"

# the current time at invocation
current_secs=$(date '+%s')

# loop through range of possible values
while [ 1 ]; do
   # calculate 'moving' seconds
   moving_secs=$(date '+%s' -d NOW+${emc}"sec")

   # hash of secret and 'current time'
   s_hash=$(echo "${secret}${moving_secs}" | sha1sum | cut -d' ' -f1)

   # print every value checked and hilight the value related to the current time
   if [ "${u_hash}" = "${s_hash}" ]; then
      echo -e "\e[1;32;40m${moving_secs} matched\e[0m"
      echo -e "\e[1;32;40m${u_hash} matched \e[1;36;40m${s_hash}\e[0m"
      match="${s_hash}"
      
      # add to hashe-cache
      echo "${current_secs} ${s_hash}" >> ${output}
   else
      echo "moving secs: ${moving_secs}"
   fi

   # only calculate up to "emc" seconds to account for different wall clocks
   if [ "${emc}" -ge ${LIMIT} ]; then
      break
   fi

   # next time slice to calculate 
   emc="$((emc + 1))"

done

# reap old values from file once $LIMIT time has passed?
# use awk to filter out already used hashes older than $reap_hours
stale_secs=$(date '+%s' -d NOW-${reap_hours}hour)
new_hashe=`mktemp --suffix=.hotp.txt`
cat ${output} | awk "\$1>=${stale_secs}" > ${new_hashe}
nreaped=$(diff ${output} ${new_hashe} | grep '<' | wc -l)
mv "${new_hashe}" "${output}" || { echo "Unable to properly reap used hashes. Permissions?"; }

echo "range         : +/- ${emc}"
echo "user hash     : ${u_hash}"
echo "server hash   : ${s_hash}"
echo "match         : ${match}"
echo "reap count    : ${nreaped}"

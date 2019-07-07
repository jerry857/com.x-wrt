#!/bin/sh

CFGS=${CFGS-"`cat feeds/x/rom/lede/cfg.list`"}

bins="`find bin/targets/ | grep -- '\(-ext4-sdcard\|-squashfs\|-factory\|-sysupgrade\)' | grep "natcap\|x-wrt" | grep -v vmlinux | grep -v '\.dtb$' | while read line; do basename $line; done`"

sha256sums="`find bin/targets/ -type f -name sha256sums`"
sha256sums=`cat $sha256sums`

targets=$(cd feeds/x/rom/lede/ && cat $CFGS | grep TARGET_DEVICE_.*=y | sed 's/CONFIG_//;s/=y//' | sort)

echo -n >map.sha256sums
echo -n >map.list

echo sha256sums: map.sha256sums >>map.list

x86bin="`find bin/targets/ | grep -- '\(-combined\|-uefi\)' | sort | while read line; do basename $line; done`"
test -n "$x86bin" && {
	echo x86_64 or x86:
	echo "$x86bin"
	echo
	for bin in $x86bin; do
		echo "$sha256sums" | grep "$bin" >>map.sha256sums
		case $bin in
			*x86-64-combined*)
				echo "x86 64bits (MBR dos):$bin" >>map.list
			;;
			*x86-64-uefi*)
				echo "x86 64bits (UEFI gpt):$bin" >>map.list
			;;
			*x86-generic-combined*)
				echo "x86 generic (MBR dos):$bin" >>map.list
			;;
			*x86-generic-uefi*)
				echo "x86 generic (UEFI gpt):$bin" >>map.list
			;;
			*)
				echo "x86_64 or x86:$bin" >>map.list
			;;
		esac
	done
}

for t in $targets; do
	tt=`echo $t | sed 's/_DEVICE_/:/g'`
	name=`echo $tt | cut -d: -f3`
	echo $tt | cut -d: -f2 | sed 's/_/ /' | while read arch subarch; do
		test -n "$arch" || continue
		text=`cat target/linux/$arch/image/*.mk target/linux/$arch/image/Makefile 2>/dev/null | grep "define .*Device\/$name$" -A50 | while read line; do [ "x$line" = "xendef" ] && break; echo $line; done`
		dis=`echo "$text" | grep "DEVICE_TITLE.*:=" | head -n1 | sed 's/DEVICE_TITLE.*:=//'`
		test -n "$dis" || {
			dis=`echo "$text" | grep '$(call Device' | head -n1 | cut -d, -f2 | sed 's/)$//g'`
		}
		test -n "$dis" || {
			VENDOR=`echo "$text" | grep "DEVICE_VENDOR.*=" | head -n1 | sed 's/DEVICE_VENDOR.*=//'`
			MODEL=`echo "$text" | grep "DEVICE_MODEL.*=" | head -n1 | sed 's/DEVICE_MODEL.*=//'`
			VARIANT=`echo "$text" | grep "DEVICE_VARIANT.*=" | head -n1 | sed 's/DEVICE_VARIANT.*=//'`
			test -n "$MODEL" && dis="$MODEL"
			test -n "$VARIANT" && dis="$dis $VARIANT"
			if test -n "$VENDOR"; then
				dis="$VENDOR $dis"
			else
				#get VENDOR
				while :; do
				SUBDEF=`echo "$text" | grep '$(Device/' | head -n1 | sed 's,$(Device/,,;s/)$//'`
				text1=`cat target/linux/$arch/image/*.mk target/linux/$arch/image/Makefile 2>/dev/null | grep "define .*Device\/$SUBDEF$" -A50 | while read line; do [ "x$line" = "xendef" ] && break; echo $line; done`
				VENDOR=`echo "$text1" | grep "DEVICE_VENDOR.*=" | head -n1 | sed 's/DEVICE_VENDOR.*=//'`
				if test -n "$VENDOR"; then
					dis="$VENDOR $dis"
				else
					#get VENDOR
					text="$text1"
				fi
				test -n "$VENDOR" && break
				test -n "$text" || {
					echo no VENDOR found
					exit 1
					break
				}
				done
			fi
		}
		bin=`echo "$bins" | grep $arch | grep -i "\($name-ex\|$name-sq\|$name-fa\|$name-ub\|$name-ue\|$name-in\)"`
		test -n "$bin" || {
			name=`echo $name | tr _ -`
			bin=`echo "$bins" | grep -i "\($name-ex\|$name-sq\|$name-fa\|$name-ub\|$name-ue\|$name-in\)"`
			test -n "$bin" || {
				bin=$(echo "$bins" | grep -i "`echo $name | head -c5`" | grep $arch)
				test -n "$bin" || {
					bin=$(echo "$bins" | grep -i "`echo $name | head -c3`" | grep $arch)
				}
			}
		}
		echo "`echo $dis`:"
		for i in $bin; do
			echo $i;
			echo "$sha256sums" | grep "$i" >>map.sha256sums
		done
		echo
		echo "`echo $dis`:"$bin >>map.list
	done
done | while read line; do echo $line; done

find bin/targets/ | grep -q -- -sdk- || {
	echo no sdk build.
	exit 0
}
find bin/targets/ | grep -- -sdk- | while read s; do basename $s; done | sort >sdk_map.list
find bin/targets/ | grep -- -sdk- >sdk_upload.list
echo -n >sdk_map.sha256sums
cat sdk_map.list | while read bin; do
	echo "$sha256sums" | grep "$bin" >>sdk_map.sha256sums
done

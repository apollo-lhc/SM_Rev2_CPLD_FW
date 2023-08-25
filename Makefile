ISE_SOURCE=/opt/Xilinx/ise/14.7/ISE_DS/settings64.sh

TOP_NAME=top
BUILD_PATH=./proj/
UCF_FILE=../src/top.ucf
FILE_LIST="../src/top.vhd"

LOG_FILE=make_log.txt

NGC_FILE=${TOP_NAME}.ngc
XST_FILE=${TOP_NAME}.xst
NGD_FILE=${TOP_NAME}.ngd
VM6_FILE=${TOP_NAME}.vm6
CMD_SETUP=cd ${BUILD_PATH} && source ${ISE_SOURCE}


${BUILD_PATH}/${TOP_NAME}.jed

%.jed:%.vm6
	${CMD_SETUP} && hprep6 -s IEEE1149 -i $<

%.vm6:%.ngd
	${CMD_SETUP} && cpldfit -intstyle ise -p xc2c64a-7-VQ100 -ofmt vhdl -optimize density -htmlrpt -loc on -slew fast -init low -inputs 32 -pterms 28 -unused keeper -terminate keeper -iostd LVCMOS33 $@

%.ngd:%.ngc ${UCF_FILE}
	${CMD_SETUP} && ngdbuild -intstyle ise -dd _ngo -uc ${UCF_FILE} -p xc2c64a-VQ100-7 $< $@ | tee -a ngdbuild.${LOG_FILE}

%.ngc:%.xst %.prj
	rm ${LOG_FILE}
	mkdir -p ${BUILD_PATH}xst/projnav.tmp/
	${CMD_SETUP} && xst -intstyle ise -ifn "$<" | tee -a xst.${LOG_FILE}

%.prj : 
	cd ${BUILD_PATH} && @echo ${FILE_LIST} | awk '{print "vhdl work \"" $$1 "\""}' > $@


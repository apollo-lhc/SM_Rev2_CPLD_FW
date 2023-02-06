#!/usr/bin/env python3

import argparse
import subprocess
import os
import signal
import time
import uuid
import jinja2

#vivado hw manager script
xvc_script = """
open_hw_manager
connect_hw_server -quiet -verbose -url localhost:{{local_port}}
open_hw_target -quiet -xvc_url {{xvc_ip}}:{{xvc_port}}
puts \"xvc running\"
"""

ise_script = """
setMode -bs
setCable -target "xilinx_tcf URL=tcp:localhost:{{local_port}}"
Identify -inferir 
identifyMPM 
assignFile -p 1 -file "{{jed_file}}"
Program -p 1 -e -v 
quit
"""


def parse_cli():
    """Parse command line arguments and make some checks on the arguments."""
    parser = argparse.ArgumentParser()

    parser.add_argument('--VIVADO_SOURCE', default="/work/Xilinx/Vivado/2020.2/settings64.sh", help='path to vivado sourcing script')

    parser.add_argument('--ISE_SOURCE', default="/work/Xilinx/ise/14.7/ISE_DS/settings64.sh", help='path to ise sourcing script')

    parser.add_argument('--HW_SERV_PORT', default="3129", help='port to run the hw_server on')

    parser.add_argument('--xvc_ip'  , default=None, help='IP of xvc server for CPLD')
    parser.add_argument('--xvc_port', default=2545, help='port of xvc server for CPLD')
    parser.add_argument('--jed_file', default=None, help='jed file to program the CPLD')

    args = parser.parse_args()

    return args


def main():
    # Parse command line arguments
    args = parse_cli()
      
    #############################################################################
    #open HW server
    #############################################################################
    hw_serv_cmd="source "+args.VIVADO_SOURCE+";hw_server -s tcp::"+str(args.HW_SERV_PORT)
    print(hw_serv_cmd)
    hw_serv_proc = subprocess.Popen(hw_serv_cmd,shell=True,preexec_fn=os.setsid)
    

    #############################################################################
    #open vivado for xvc
    #############################################################################
    #create the config files
    xvc_script_data= jinja2.Environment().from_string(xvc_script)
    outFileName1="/tmp/"+str(uuid.uuid4())+"_xvc.tcl"
    outFile = open(outFileName1,"w")
    outFile.write(xvc_script_data.render(local_port=args.HW_SERV_PORT,
                                         xvc_ip=args.xvc_ip,
                                         xvc_port=args.xvc_port)
    )
    outFile.close()
    xvc_cmd="source "+args.VIVADO_SOURCE+";vivado -mode tcl  -source "+outFileName1
    print(xvc_cmd)
    xvc_proc = subprocess.Popen(xvc_cmd,
                                shell=True,
                                preexec_fn=os.setsid,
                                stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE,
                                stdin=subprocess.PIPE)
    

    #wait for xvc to be loaded
    while(True):
        outs = xvc_proc.stdout.readline()
        if outs == None:
            continue
        outs = str(outs.decode('utf-8'))

        print(outs,end='')
        if outs.find('xvc running') > -1:
            break

        
    #############################################################################
    #Prog
    #############################################################################
    ise_script_data= jinja2.Environment().from_string(ise_script)
    outFileName2="/tmp/"+str(uuid.uuid4())+"_ise.cmd"
    outFile = open(outFileName2,"w")
    outFile.write(ise_script_data.render(local_port=args.HW_SERV_PORT,
                                         jed_file=args.jed_file
    ))
    outFile.close()

    ise_cmd="source "+args.ISE_SOURCE+"; impact -batch "+outFileName2
    print(ise_cmd)
    ise_proc = subprocess.Popen(ise_cmd,shell=True,preexec_fn=os.setsid)

    
    #wait to finish
    ise_proc.wait()
    print("Done programming")
    os.remove(outFileName2)   
       
    #kill vivado xvc
    print("Shutting down Vivado")
    os.killpg(os.getpgid(xvc_proc.pid), signal.SIGTERM)
    xvc_proc.wait()
    os.remove(outFileName1)   
#    os.killpg(os.getpgid(xvc_proc.pid), signal.SIGTERM) 

    print("Shutting down hw_serv")
    #kill HW server
    os.killpg(os.getpgid(hw_serv_proc.pid), signal.SIGINT)
    hw_serv_proc.wait()
    

if __name__ == '__main__':
    main()

    

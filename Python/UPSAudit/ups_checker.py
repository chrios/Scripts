'''
Dell UPS Checker tool
Author: Christopher Frew
Date: 10/10/2019
Version: 1.0
Add your UPS hostnames into hosts.txt
'''

import urllib.request
import urllib.parse
import csv
from pysnmp.hlapi import *
import socket

# Define some variables, change to suit
communityString = 'community'
snmpPort = 161
results = []
resultsFileName = 'ups_checker_results.csv'
upses = open('hosts.txt').read().splitlines()

# ObjectIdentities to be used in the SNMP Get command
ifPhyAddress = ObjectIdentity('1.3.6.1.2.1.2.2.1.6.2')
productStatusGlobalStatus = ObjectIdentity('1.3.6.1.4.1.674.10902.2.110.1.0')
physicalIdentSerialNumber = ObjectIdentity('1.3.6.1.4.1.674.10902.2.120.1.2.0')
physicalBatteryABMStatus = ObjectIdentity('1.3.6.1.4.1.674.10902.2.120.5.1.0')
physicalBatteryTestStatus = ObjectIdentity('1.3.6.1.4.1.674.10902.2.120.5.2.0')
physicalBatterySecondsRemaining = ObjectIdentity('1.3.6.1.4.1.674.10902.2.120.5.3.0')

# Returns Dell Advanced Battery Management Status from code
def dellABMStatus(code):
    if code == 1:
        return 'Charging'
    elif code == 2:
        return 'Discharging'
    elif code == 3:
        return 'Floating'
    elif code == 4:
        return 'Resting'
    elif code == 5:
        return 'Off'

# Returns Dell Battery Self Test status message
def dellBatteryTestStatus(code):
    if code == 1:
        return 'Done, Passed'
    elif code == 2:
        return 'Done, Warning'
    elif code == 3:
        return 'Done, Error'
    elif code == 4:
        return 'Aborted'
    elif code == 5:
        return 'In Progress'
    elif code == 6:
        return 'No Test Initiated'
    elif code == 7:
        return 'Test Scheduled'

# Returns Dell Global Status message
def dellGlobalStatus(code):
    if code == 1:
        return 'Other'
    elif code == 2:
        return 'Unknown'
    elif code == 3:
        return 'OK'
    elif code == 4:
        return 'Non-Critical'
    elif code == 5:
        return 'Critical'
    elif code == 6:
        return 'Non-Recoverable'

# Iterate through UPS's in hosts.txt file
for ups in upses:
    print('----------')
    print('attempting to connect to ups', ups, '...')
    try:
        # Check if DNS name resolves
        upsIpAddress = socket.gethostbyname(ups)
        errorIndication, errorStatus, errorIndex, varBinds = next(
            getCmd(
                SnmpEngine(), 
                CommunityData('DET_READ', mpModel=0), 
                UdpTransportTarget((upsIpAddress, snmpPort)), 
                ContextData(),
                ObjectType(ifPhyAddress),
                ObjectType(productStatusGlobalStatus),
                ObjectType(physicalIdentSerialNumber),
                ObjectType(physicalBatteryABMStatus),
                ObjectType(physicalBatteryTestStatus),
                ObjectType(physicalBatterySecondsRemaining),
                lookupMib=False
            )
        )
        # If SNMP errors out
        if errorIndication:
            print(errorIndication, ups)
        else:
            print('Successfully connected to', ups)
            # Write results to results array
            results.append({
                    'Name': ups,
                    'UPS_MAC': varBinds[0][1].prettyPrint(),
                    'UPS_SerialNumber': varBinds[2][1].prettyPrint(),
                    'UPS_GlobalStatus': dellGlobalStatus(varBinds[1][1]),
                    'UPS_ABMStatus': dellABMStatus(varBinds[3][1]),
                    'UPS_BatteryTestStatus': dellBatteryTestStatus(varBinds[4][1]),
                    'UPS_BatterySecondsRemaining': varBinds[5][1].prettyPrint()
            })
    # Catches error from socket.gethostbyname()
    except:
        print(ups, 'is an invalid host!')

# Write results array to CSV
writer = csv.DictWriter(
    open(resultsFileName, 'w', newline=''),
    fieldnames=results[0].keys(),
    delimiter=',',
    quotechar='"'
)
writer.writeheader()
for result in results:
    writer.writerow(result)
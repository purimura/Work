# -*- coding: utf-8 -*-
# ---------------------------------------------------------------------------
# Created By    : Ponlawat Rattanavayakorn
# Created Date  : 20 Jan 2022
# Last Modified : 18 Feb 2022
# ---------------------------------------------------------------------------

import os
import csv
import sys
import time
import base64
import socket
import logging
import paramiko
import requests
import subprocess
from contextlib import closing
from datetime import datetime, timedelta

def sendLine(message):
    try:
        requests.post('https://notify-api.line.me/api/notify', data={'message':message},
            headers={'content-type':'application/x-www-form-urlencoded','Authorization':'Bearer '+token})
    except:
        message = message.replace('\n', ',')
        with open(file=os.path.dirname(os.path.realpath(__file__)) + '/conf/line.tmp', mode='a') as f:
            f.write(datetime.now().strftime('%d/%m/%Y %H:%M:%S') + ',' + message + '\n')

def recoveryLine():
    if os.path.isfile(os.path.dirname(os.path.realpath(__file__)) + '/conf/line.tmp'):
        with open(file=os.path.dirname(os.path.realpath(__file__)) + '/conf/line.tmp', mode='r') as f:
            message = f.readlines()
        os.remove(os.path.dirname(os.path.realpath(__file__)) + '/conf/line.tmp')
        message = [ i.replace('\n', '') for i in message ]
        message = [ i.replace(',', '\n') for i in message ]
        for x in message:
            try:
                requests.post('https://notify-api.line.me/api/notify', data={'message':x},
                    headers={'content-type':'application/x-www-form-urlencoded','Authorization':'Bearer '+token})
            except:
                x = x.replace('\n', ',')
                with open(file=os.path.dirname(os.path.realpath(__file__)) + '/conf/line.tmp', mode='a') as f:
                    f.write(x + '\n')

def sshConnect(host, user, passwd):
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    for i in range(3):
        try:
            ssh.connect(hostname=host, username=user, password=passwd)
            return ssh
        except:
            if i != 2:
                time.sleep(3)
            else:
                return []

def mainPing():
    linePing = 'Ping Failed'
    for x in data['hosts']:
        if len(x) != 2:
            logging.error('Ping missing config')
            linePing += '\nMissing config'
            continue
        if x[0][0] == '#':
            x[0] = x[0][1:]
            sharp = True
        else:
            sharp = False
        try:
            if os.name == 'nt':
                output = subprocess.check_output(f'ping -n 2 {x[0]}', shell=True, universal_newlines=True)
            else:
                output = subprocess.check_output(f'ping -c 2 {x[0]}', shell=True, universal_newlines=True)
        except:
            logging.error(f'Ping {x[0]} {x[1]} Failed')
            linePing += f'\n{x[0]}  {x[1]}'
            continue
        output = output.split('\n')
        output = [ s for s in output if s ]
        if sharp == True:
            if 'unreachable' in output[1] and 'unreachable' in output[2]:
                logging.error(f'Ping {x[0]} {x[1]} Failed')
            else:
                logging.info(f'Ping {x[0]} {x[1]} Online')
                sendLine(f'Ping Info\n{x[0]}  {x[1]}\nOnline !!!')
                with open(file=os.path.dirname(os.path.realpath(__file__)) + '/conf/hosts.conf', mode='r') as file :
                    filedata = file.read()
                filedata = filedata.replace(f'#{x[0]},{x[1]}', f'{x[0]},{x[1]}')
                with open(file=os.path.dirname(os.path.realpath(__file__)) + '/conf/hosts.conf', mode='w') as file:
                    file.write(filedata)
        else:
            if 'unreachable' in output[1] and 'unreachable' in output[2]:
                logging.error(f'Ping {x[0]} {x[1]} Failed')
                linePing += f'\n{x[0]}  {x[1]}'
            else:
                logging.info(f'Ping {x[0]} {x[1]}')
    if linePing != 'Ping Failed': sendLine(linePing)

def mainPort():
    linePort = 'Port Failed'
    for x in data['port']:
        if len(x) < 2:
            logging.error('Port missing config')
            linePort += '\nMissing config'
            continue
        for y in x[1:]:
            with closing(socket.socket(socket.AF_INET, socket.SOCK_STREAM)) as sock:
                if sock.connect_ex((x[0], int(y))) != 0:
                    logging.error(f'Check {x[0]} Port {y} Failed')
                    linePort += f'\n{x[0]}  {y}'
                else:
                    logging.info(f'Check {x[0]} Port {y}')
    if linePort != 'Port Failed': sendLine(linePort)

def mainWeb():
    lineWeb = 'Web Failed'
    for url in data['web']:
        url = url[0]
        try:
            r = requests.get(url, verify=False, timeout=10)
        except:
            logging.error(f'Check web {url} Failed')
            splitURL = url.split('/')
            shortURL = splitURL[0] + '//' + splitURL[2]
            lineWeb += f'\n{shortURL}'
            continue
        if r.status_code != 200:
            logging.error(f'Check web {url} Failed')
            splitURL = url.split('/')
            shortURL = splitURL[0] + '//' + splitURL[2]
            lineWeb += f'\n{shortURL}'
        else:
            logging.info(f'Check web {url}')
    if lineWeb != 'Web Failed': sendLine(lineWeb)

def mainBackup():
    logList = ['Backup complete!', 'All database backups complete!']
    lineBackup = 'Backup Failed'
    yesterday = datetime.now() - timedelta(1)
    for x in data['backup']:
        if len(x) < 2:
            logging.error('Backup missing config')
            lineBackup += '\nMissing config'
            continue
        login = [ i for i in data['passwd'] if i[0] == x[0] ]
        if not login:
            logging.error(f'Backup {x[0]} No data login')
            lineBackup += f'\n{x[0]}  No data login'
            continue
        ssh = sshConnect(x[0], login[0][1], login[0][2])
        if not ssh:
            logging.error(f'backup {x[0]} Login failed')
            lineBackup += f'\n{x[0]}  Login failed'
            continue
        for y in x[1:]:
            y = y.replace('%Y', yesterday.strftime('%Y'))
            y = y.replace('%m', yesterday.strftime('%m'))
            y = y.replace('%d', yesterday.strftime('%d'))
            ssh_stdin, ssh_stdout, ssh_stderr = ssh.exec_command(f'ls -d {y}')
            result = ssh_stdout.readlines()
            if not result: result = ssh_stderr.readlines()
            if not result:
                logging.error(f'Result backup {x[0]} None')
                lineBackup += f'\n{x[0]}  None'
                continue
            result = result[0]
            if 'No such file or directory' in result:
                logging.error(f'Check {x[0]} Backup {y} No such file or directory')
                shortBackup = y.split('/')[-1]
                lineBackup += f'\n{x[0]}  {shortBackup}'
            elif 'Permission denied' in result:
                logging.error(f'Check {x[0]} Backup {y} Permission denied')
                shortBackup = y.split('/')[-1]
                lineBackup += f'\n{x[0]}  {shortBackup}'
            else:
                if y[-4:] != '.log':
                    logging.info(f'Check {x[0]} Backup {y}')
                else:
                    ssh_stdin, ssh_stdout, ssh_stderr = ssh.exec_command(f'cat {y}')
                    result = str(ssh_stdout.read())
                    if not result:
                        logging.error(f'Check {x[0]} Log backup {y} not found word')
                        shortBackup = y.split('/')[-1]
                        lineBackup += f'\n{x[0]}  {shortBackup}'
                        continue
                    checkLog = [ i for i in logList if i in result ]
                    if not checkLog:
                        logging.error(f'Check {x[0]} Log backup {y} not found word')
                        shortBackup = y.split('/')[-1]
                        lineBackup += f'\n{x[0]}  {shortBackup}'
                    else:
                        logging.info(f'Check {x[0]} Log backup {y}')
    if lineBackup != 'Backup Failed': sendLine(lineBackup)

def mainCPU():
    skipCPU = []
    lineCPU = 'CPU Usage'
    for x in data['passwd']:
        if len(x) != 3:
            logging.error('CPU missing config')
            lineCPU += '\nMissing config'
            continue
        ssh = sshConnect(x[0], x[1], x[2])
        if not ssh:
            logging.error(f'CPU {x[0]} Login failed')
            lineCPU += f'\n{x[0]}  Login failed'
            continue
        ssh_stdin, ssh_stdout, ssh_stderr = ssh.exec_command('top -b -n 1 | grep Cpu')
        result = ssh_stdout.readlines()
        if not result:
            ssh_stdin, ssh_stdout, ssh_stderr = ssh.exec_command('top -n 1 | grep states')
            result = ssh_stdout.readlines()
        if not result:
            logging.error(f'Result CPU Usage {x[0]} None')
            lineCPU += f'\n{x[0]}  None'
            continue
        result = result[0]
        if 'ni,' in result:
            result = result.replace('ni,', '')
            cpu = 100 - float(result.split()[6])
        else:
            result = result.replace('%', '')
            cpu = 100 - float(result.split()[2])
        checkCPU = list(filter(lambda s: s == x[0], skipCPU))
        if cpu >= 90 and not checkCPU:
            logging.warning(f'Check {x[0]} CPU Usage {cpu:.1f}%')
            lineCPU += f'\n{x[0]}  {cpu:.1f}%'
        else:
            logging.info(f'Check {x[0]} CPU Usage {cpu:.1f}%')
    if lineCPU != 'CPU Usage': sendLine(lineCPU)

def mainDisk():
    skipDisk = []
    lineDisk = 'Disk Usage'
    for x in data['passwd']:
        if len(x) != 3:
            logging.error('Disk missing config')
            lineDisk += '\nMissing config'
            continue
        ssh = sshConnect(x[0], x[1], x[2])
        if not ssh:
            logging.error(f'Disk {x[0]} Login failed')
            lineDisk += f'\n{x[0]}  Login failed'
            continue
        ssh_stdin, ssh_stdout, ssh_stderr = ssh.exec_command('df -h')
        result = ssh_stdout.readlines()
        if not result:
            logging.error(f'Result Disk Usage {x[0]} None')
            lineDisk += f'\n{x[0]}  None'
            continue
        result = [ i.replace('\n', '') for i in result ]
        result = [ i.replace('%', '') for i in result ]
        for y in result:
            word = y.split()
            if word[4].isnumeric():
                checkDisk = list(filter(lambda s: s in word[5], skipDisk))
                if int(word[4]) >= 90 and not checkDisk:
                    logging.warning(f'Check {x[0]} Disk Usage {word[4]}% {word[5]}')
                    lineDisk += f'\n{x[0]}  {word[4]}%  {word[5]}'
                else:
                    logging.info(f'Check {x[0]} Disk Usage {word[4]}% {word[5]}')
    if lineDisk != 'Disk Usage': sendLine(lineDisk)

def mainMemory():
    skipMemory = []
    lineMemory = 'Memory Usage'
    for x in data['passwd']:
        if len(x) != 3:
            logging.error('Memory missing config')
            lineMemory += '\nMissing config'
            continue
        ssh = sshConnect(x[0], x[1], x[2])
        if not ssh:
            logging.error(f'Memory {x[0]} Login failed')
            lineMemory += f'\n{x[0]}  Login failed'
            continue
        ssh_stdin, ssh_stdout, ssh_stderr = ssh.exec_command('free | grep Mem:')
        result = ssh_stdout.readlines()
        if not result:
            ssh_stdin, ssh_stdout, ssh_stderr = ssh.exec_command('top -n 1 | grep Memory:')
            result = ssh_stdout.readlines()
        if not result:
            logging.error(f'Result Memory Usage {x[0]} None')
            lineMemory += f'\n{x[0]}  None'
            continue
        result = result[0]
        if 'Mem:' in result:
            total = result.split()[1]
            free = result.split()[3]
            memory = 100 - ((float(free) / float(total)) * 100)
        else:
            f = lambda m: float(m.replace('G', ''))*1048576 if 'G' in m else (float(m.replace('M', ''))*1024 if 'M' in m else m)
            total = result.split()[1]
            total = f(total)
            free = result.split()[4]
            free = f(free)
            memory = 100 - ((float(free) / float(total)) * 100)
        checkMemory = list(filter(lambda s: s == x[0], skipMemory))
        if memory >= 90 and not checkMemory:
            logging.warning(f'Check {x[0]} Memory Usage {memory:.1f}%')
            lineMemory += f'\n{x[0]}  {memory:.1f}%'
        else:
            logging.info(f'Check {x[0]} Memory Usage {memory:.1f}%')
    if lineMemory != 'Memory Usage': sendLine(lineMemory)

def mainProcess():
    lineProcess = 'Process Failed'
    for x in data['process']:
        if len(x) < 2:
            logging.error('Process missing config')
            lineProcess += '\nMissing config'
            continue
        login = [ i for i in data['passwd'] if i[0] == x[0] ]
        if not login:
            logging.error(f'Process {x[0]} No data login')
            lineProcess += f'\n{x[0]}  No data login'
            continue
        ssh = sshConnect(x[0], login[0][1], login[0][2])
        if not ssh:
            logging.error(f'Process {x[0]} Login failed')
            lineProcess += f'\n{x[0]}  Login failed'
            continue
        for y in x[1:]:
            ssh_stdin, ssh_stdout, ssh_stderr = ssh.exec_command(f'ps -ef | grep {y}')
            result = ssh_stdout.readlines()
            if not result:
                logging.error(f'Result Process {x[0]} None')
                lineProcess += f'\n{x[0]}  None'
                continue
            if len(result) < 3:
                logging.error(f'Check {x[0]} Process {y} Failed')
                shortProcess = y.split('/')[-1]
                lineProcess += f'\n{x[0]}  {shortProcess}'
            else:
                logging.info(f'Check {x[0]} Process {y}')
    if lineProcess != 'Process Failed': sendLine(lineProcess)

if __name__ == '__main__':
    token = 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'
    recoveryLine()

    if not os.path.exists(os.path.dirname(os.path.realpath(__file__)) + '/logs'): os.makedirs(os.path.dirname(os.path.realpath(__file__)) + '/logs')
    for filename in os.listdir(os.path.dirname(os.path.realpath(__file__)) + '/logs'):
        if os.path.getmtime(os.path.join(os.path.dirname(os.path.realpath(__file__)) + '/logs', filename)) < time.time() - 7 * 86400:
            os.remove(os.path.join(os.path.dirname(os.path.realpath(__file__)) + '/logs', filename))

    requests.packages.urllib3.disable_warnings()
    logging.basicConfig(filename=os.path.dirname(os.path.realpath(__file__)) + '/logs/' + datetime.now().strftime('%Y-%m-%d') +'.log',
                        format='%(asctime)s [ %(levelname)-8s ] %(message)s', datefmt='%H:%M:%S', level=logging.INFO)

    start = datetime.now().strftime('%d/%m/%Y %H:%M:%S')
    logging.info(f'Start {start}')

    data = dict()
    config = ['backup', 'hosts', 'passwd', 'port', 'process', 'web']

    for x in config:
        with open(file=os.path.dirname(os.path.realpath(__file__)) + '/conf/' + x + '.conf', mode='r') as f:
            data[x] = list(csv.reader(f))
        data[x] = [ i for i in data[x] if i != [] ]
        data[x] = [[ j.replace(' ', '') for j in i ] for i in data[x] ]
        try:
            if x == 'passwd': data[x] = list(map(lambda data: [data[0], data[1], base64.b64decode(data[2]).decode('utf-8')], data[x]))
        except:
            pass

    if len(sys.argv) == 1: sys.argv.append('all')
    for arg in sys.argv[1:]:
        arg = arg.lower()
        if arg == 'ping':
            mainPing()
        elif arg == 'port':
            mainPort()
        elif arg == 'web':
            mainWeb()
        elif arg == 'backup':
            mainBackup()
        elif arg == 'cpu':
            mainCPU()
        elif arg == 'disk':
            mainDisk()
        elif arg == 'memory':
            mainMemory()
        elif arg == 'process':
            mainProcess()
        elif arg == 'all':
            mainPing()
            mainPort()
            mainWeb()
            mainBackup()
            mainCPU()
            mainDisk()
            mainMemory()
            mainProcess()
        else:
            logging.error(f'Missing argument {arg}')
    logging.info(f'End {start} - ' + datetime.now().strftime('%d/%m/%Y %H:%M:%S'))
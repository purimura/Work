โปรแกรม Monitor Server และแจ้งเตือนผ่าน Line Notify

รายละเอียดของแต่ละ Function
1. Ping - Monitor Server จากการ Ping
2. Port - Monitor Server จากการตรวจสอบ Port
3. Web - Monitor Website
4. Backup - Monitor ไฟล์ Backup เมื่อวานของ Linux Server
5. CPU - Monitor CPU เมื่อมากกว่า 90% ของ Linux Server
6. Disk - Monitor Disk ที่ใช้งานมากกว่า 90% ของ Linux Server
7. Memory - Monitor Memory เมื่อมากกว่า 90% ของ Linux Server
8. Process - Monitor Process ที่ใช้งานของ Linux Server

วิธีการติดตั้ง (สามารถติดตั้งได้ทั้ง Windows และ Linux)
1. ติดตั้ง Python Version 3
2. ติดตั้ง Library ของ Python ด้วยคำสั่ง pip install -r requirements.txt
3. สร้าง Line Token ที่ https://notify-bot.line.me/ และนำ token ไปใส่ในตัวแปร token ของไฟล์ monitor.py

วิธีตั้งค่า Function
1. Ping ตั้งค่าที่ไฟล์ hosts.conf
	- ไฟล์ hosts.conf ใส่ค่าแต่ละแถวด้วย IP และ Hostname เช่น 192.168.1.1,Database01
2. Port ตั้งค่าที่ไฟล์ port.conf
	- ไฟล์ port.conf ใส่ค่าแต่ละแถวด้วย IP และ Port (สามารถใส่หลาย Port ได้) เช่น 192.168.1.1,80,8443
3. Web ตั้งค่าที่ไฟล์ web.conf
	- ไฟล์ web.conf ใส่ค่าแต่ละแถวด้วย URL เช่น https://www.google.com
4. Backup ตั้งค่าที่ไฟล์ passwd.conf และ backup.conf
	- ไฟล์ passwd.conf ใส่ค่าแต่ละแถวด้วย IP, Username และ Password ที่แปลงเป็น Base64 เช่น 192.168.1.1,root,cGFzc3dvcmQ=
	- ไฟล์ backup.conf ใส่ค่าแต่ละแถวด้วย IP, Full path ของไฟล์ Backup เช่น 192.168.1.1,/root/%d-%m-%Y-*.bak
		(%d, %m, %Y แทนวันเดือนปีของเมื่อวานและ * แทน Wildcard)
5. CPU ตั้งค่าที่ไฟล์ passwd.conf
	- ไฟล์ passwd.conf ใส่ค่าแต่ละแถวด้วย IP, Username และ Password ที่แปลงเป็น Base64 เช่น 192.168.1.1,root,cGFzc3dvcmQ=
6. Disk ตั้งค่าที่ไฟล์ passwd.conf
	- ไฟล์ passwd.conf ใส่ค่าแต่ละแถวด้วย IP, Username และ Password ที่แปลงเป็น Base64 เช่น 192.168.1.1,root,cGFzc3dvcmQ=
7. Memory ตั้งค่าที่ไฟล์ passwd.conf
	- ไฟล์ passwd.conf ใส่ค่าแต่ละแถวด้วย IP, Username และ Password ที่แปลงเป็น Base64 เช่น 192.168.1.1,root,cGFzc3dvcmQ=
8. Process ตั้งค่าที่ไฟล์ passwd.conf และ process.conf
	- ไฟล์ passwd.conf ใส่ค่าแต่ละแถวด้วย IP, Username และ Password ที่แปลงเป็น Base64 เช่น 192.168.1.1,root,cGFzc3dvcmQ=
	- ไฟล์ process.conf ใส่ค่าแต่ละแถวด้วย IP และ ชื่อ Process (สามารถใส่หลาย Process ได้) เช่น 192.168.1.1,pgsql
	
วิธี Run โปรแกรม
	เปิด Command Prompt หรือ Terminal ใช้คำสั่ง python monitor.py ตามด้วย Function (สามารถใส่หลาย Function ได้)
	เช่น python monitor.py ping port web

วิธีตั้งค่า Task schedule
1. Windows
	- ตั้งค่า Triggers เป็นเวลาที่ต้องการ Run โปรแกรม
	- ตั้งค่า Actions โดย Program/script เลือกไฟล์ python.exe และ Add arguments ใส่ Full path ของ monitor.py เว้นวรรคตามด้วย Function
2. Linux
	- ตั้งค่า crontab เช่น */15 * * * * /usr/local/bin/python3.8 /root/monitor.py ping port web disk
	
โปรแกรม Monitor Server และแจ้งเตือนผ่าน Line Notify<br />
<br />
รายละเอียดของแต่ละ Function<br />
1. Ping - Monitor Server จากการ Ping<br />
2. Port - Monitor Server จากการตรวจสอบ Port<br />
3. Web - Monitor Website<br />
4. Backup - Monitor ไฟล์ Backup เมื่อวานของ Linux Server<br />
5. CPU - Monitor CPU เมื่อมากกว่า 90% ของ Linux Server<br />
6. Disk - Monitor Disk ที่ใช้งานมากกว่า 90% ของ Linux Server<br />
7. Memory - Monitor Memory เมื่อมากกว่า 90% ของ Linux Server<br />
8. Process - Monitor Process ที่ใช้งานของ Linux Server<br />
<br />
วิธีการติดตั้ง (สามารถติดตั้งได้ทั้ง Windows และ Linux)<br />
1. ติดตั้ง Python Version 3<br />
2. ติดตั้ง Library ของ Python ด้วยคำสั่ง pip install -r requirements.txt<br />
3. สร้าง Line Token ที่ https://notify-bot.line.me/ และนำ token ไปใส่ในตัวแปร token ของไฟล์ monitor.py<br />
<br />
วิธีตั้งค่า Function<br />
1. Ping ตั้งค่าที่ไฟล์ hosts.conf<br />
	- ไฟล์ hosts.conf ใส่ค่าแต่ละแถวด้วย IP และ Hostname เช่น 192.168.1.1,Database01<br />
2. Port ตั้งค่าที่ไฟล์ port.conf<br />
	- ไฟล์ port.conf ใส่ค่าแต่ละแถวด้วย IP และ Port (สามารถใส่หลาย Port ได้) เช่น 192.168.1.1,80,8443<br />
3. Web ตั้งค่าที่ไฟล์ web.conf<br />
	- ไฟล์ web.conf ใส่ค่าแต่ละแถวด้วย URL เช่น https://www.google.com<br />
4. Backup ตั้งค่าที่ไฟล์ passwd.conf และ backup.conf<br />
	- ไฟล์ passwd.conf ใส่ค่าแต่ละแถวด้วย IP, Username และ Password ที่แปลงเป็น Base64 เช่น 192.168.1.1,root,cGFzc3dvcmQ=<br />
	- ไฟล์ backup.conf ใส่ค่าแต่ละแถวด้วย IP, Full path ของไฟล์ Backup เช่น 192.168.1.1,/root/%d-%m-%Y-*.bak<br />
		(%d, %m, %Y แทนวันเดือนปีของเมื่อวานและ * แทน Wildcard)<br />
5. CPU ตั้งค่าที่ไฟล์ passwd.conf<br />
	- ไฟล์ passwd.conf ใส่ค่าแต่ละแถวด้วย IP, Username และ Password ที่แปลงเป็น Base64 เช่น 192.168.1.1,root,cGFzc3dvcmQ=<br />
6. Disk ตั้งค่าที่ไฟล์ passwd.conf<br />
	- ไฟล์ passwd.conf ใส่ค่าแต่ละแถวด้วย IP, Username และ Password ที่แปลงเป็น Base64 เช่น 192.168.1.1,root,cGFzc3dvcmQ=<br />
7. Memory ตั้งค่าที่ไฟล์ passwd.conf<br />
	- ไฟล์ passwd.conf ใส่ค่าแต่ละแถวด้วย IP, Username และ Password ที่แปลงเป็น Base64 เช่น 192.168.1.1,root,cGFzc3dvcmQ=<br />
8. Process ตั้งค่าที่ไฟล์ passwd.conf และ process.conf<br />
	- ไฟล์ passwd.conf ใส่ค่าแต่ละแถวด้วย IP, Username และ Password ที่แปลงเป็น Base64 เช่น 192.168.1.1,root,cGFzc3dvcmQ=<br />
	- ไฟล์ process.conf ใส่ค่าแต่ละแถวด้วย IP และ ชื่อ Process (สามารถใส่หลาย Process ได้) เช่น 192.168.1.1,pgsql<br />
<br />
วิธี Run โปรแกรม<br />
	เปิด Command Prompt หรือ Terminal ใช้คำสั่ง python monitor.py ตามด้วย Function (สามารถใส่หลาย Function ได้)<br />
	เช่น python monitor.py ping port web<br />
<br />
วิธีตั้งค่า Task schedule<br />
1. Windows<br />
	- ตั้งค่า Triggers เป็นเวลาที่ต้องการ Run โปรแกรม<br />
	- ตั้งค่า Actions โดย Program/script เลือกไฟล์ python.exe และ Add arguments ใส่ Full path ของ monitor.py เว้นวรรคตามด้วย Function<br />
2. Linux<br />
	- ตั้งค่า crontab เช่น */15 * * * * /usr/local/bin/python3.8 /root/monitor.py ping port web disk
	
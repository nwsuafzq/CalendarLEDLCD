;=====================
;			Author:ZhangQiong
; 			From NWAFU
;			Date:2017年1月
;			实验环境：STAR ES598PCI实验箱
;=====================

	.MODEL	TINY
EXTRN	Display8:NEAR, GetKeyA:NEAR
IO8259_0	EQU	0F000H
IO8259_1	EQU	0F001H
Con_8253	EQU	0E003H
T0_8253		EQU	0E000H  
DATA_8279       EQU     0BF00H			;8279读写数据口的地址

;==========液晶屏LCD========
WR_COM_AD_L	EQU	0C004H			;写左半屏指令地址	;片选CS4
WR_COM_AD_R	EQU	0C000H			;写右半屏指令地址
WR_DATA_AD_L	EQU	0C006H		;写左半屏数据地址	
WR_DATA_AD_R	EQU	0C002H		;写右半屏数据地址
RD_BUSY_AD	EQU	0C001H			;查忙地址
RD_DATA_AD	EQU	0C003H			;读数据地址

X		EQU	0B8H			;起始显示行基址
Y		EQU	040H			;起始显示列基址
FirstLine	EQU	0C0H
;====================

	.STACK      200
	.DATA
halfsec		DB	0			;0.5秒计数
sec			DB	0			;秒
min			DB	0			;分
hour		DB	0			;时
day			DB 	0			;日
month		DB	0			;月
year		DW	0			;年
yearLowPos2		DB	0			;年的低两位
yearHighPos2	DB	0			;年的高两位

bufferTime					DB	8 DUP(0)		;显示时间缓冲区，8个字节
bufferTimeSetting		DB	8 DUP(0)		;显示设置时间缓冲区，8个字节
bufferDate					DB	8 DUP(0)		;显示日期缓冲区，8个字节
bufferDateSetting		DB	8 DUP(0)		;显示设置日期缓冲区，8个字节

timeNeedFlashDisp		DB	0			;时间需要刷新显示
dateNeedFlashDisp		DB	0			;日期需要刷新显示
displayTimeFlag			DB	0				;显示日期还是显示时间(显示时间为1，显示日期为0)
TimePos				DB	0				;时间位标志，设置哪一位时间
DatePos				DB	0				;日期位标志，设置哪一位日期
timeSettingFlash		DB	0			;时间设置时是否需要刷新
dateSettingFlash      	DB  0          	;日期设置时是否需要刷新
LeapYear				DB	0			;闰年标志
MonthHas30Day	DB	0			;天数为30天的月份标志

;========液晶屏LCD================
ZERO 	DB 	000H,0E0H,010H,008H,008H,010H,0E0H,000H,000H,00FH,010H,020H,020H,010H,00FH,000H
		DB  000H,010H,010H,0F8H,000H,000H,000H,000H,000H,020H,020H,03FH,020H,020H,000H,000H
		DB  000H,070H,008H,008H,008H,088H,070H,000H,000H,030H,028H,024H,022H,021H,030H,000H
		DB  000H,030H,008H,088H,088H,048H,030H,000H,000H,018H,020H,020H,020H,011H,00EH,000H
		DB  000H,000H,0C0H,020H,010H,0F8H,000H,000H,000H,007H,004H,024H,024H,03FH,024H,000H
		DB  000H,0F8H,008H,088H,088H,008H,008H,000H,000H,019H,021H,020H,020H,011H,00EH,000H
		DB  000H,0E0H,010H,088H,088H,018H,000H,000H,000H,00FH,011H,020H,020H,011H,00EH,000H
		DB  000H,038H,008H,008H,0C8H,038H,008H,000H,000H,000H,000H,03FH,000H,000H,000H,000H
		DB  000H,070H,088H,008H,008H,088H,070H,000H,000H,01CH,022H,021H,021H,022H,01CH,000H
		DB  000H,0E0H,010H,008H,008H,010H,0E0H,000H,000H,000H,031H,022H,022H,011H,00FH,000H
POINT	DB  000H,000H,000H,0C0H,0C0H,000H,000H,000H,000H,000H,000H,030H,030H,000H,000H,000H
;=============================

	.CODE  
;========================主程序========================	

START:  MOV     AX,@DATA
        MOV     DS,AX
        MOV		ES,AX
        NOP
        MOV	sec,58			;时分秒赋初值23:59:58
        MOV	min,59
        MOV	hour,23
		MOV	day,30				;年月日赋初值2017 03 30
        MOV	month,3
        MOV	yearHighPos2,20
        MOV	yearLowPos2,17
		MOV	timeNeedFlashDisp,1		;显示初始时间 置为1
		MOV dateNeedFlashDisp,0
		MOV displayTimeFlag,1    	;初始显示标志为时间 置为1
		CALL	Init8253			;调用8253初始化程序
		CALL	Init8259			;调用8259初始化程序
		CALL	WriIntver			;写中断向量表
		
		CALL  	LCDCLEAR			;清LCD屏
		CALL 	LCD_INIT			;初始化LCD
		
		STI
		
Main:   	CALL GetKeyA			;扫描按键
			JNB Key_Null			;没有按键,跳转至NoKey
			CMP AL,0EH				;按键是否>=E
			JB  Key_Blow_E			;按键<E 则跳至Key_Blow_E

Key_is_E_F:	CMP AL,0FH				;判断按键为E还是F
			JNZ Main				;按键不为F 则按键为E，取消设置，回到主程序Main
			CMP displayTimeFlag,1	;按键为F，判断正在显示时间还是日期
			JNZ DateSet				;若displayTimeFlag!=1 说明是正在显示日期 所以跳转至DataSet			
TimeSet:	CALL SetTime			;若时间显示标志位displayTimeFlag=1,说明正在显示时间，则调用SetTime设置时间子程序
TimeDisplay:CALL Display_LED_Time   ;然后调用显示时间
			MOV timeNeedFlashDisp,0
			JMP Main
				
DateNeedDisp:CMP dateNeedFlashDisp,1
			 JNZ Main		
		     CALL Display_LED_Date
			 MOV dateNeedFlashDisp,0
			 JMP Main				
				
DateSet:	CALL SetDate
			;JMP DateDisplay			;设置完日期后，需要显示新的日期，跳转至DateDisplay
DateDisplay:CALL Display_LED_Date
			MOV dateNeedFlashDisp,0		
			JMP Main					;显示完日期后，回到主程序Main	

Key_Blow_E:	CMP AL,0DH					;按键为D 			
			JNZ Key_Null 				
			NOT displayTimeFlag 		;将displayTimeFlag取反
			
Key_Null:	CMP displayTimeFlag,1
			JNZ	DateNeedDisp
			CMP timeNeedFlashDisp,1
			JNZ Main
			JMP TimeDisplay
;=================================================


;================时间设定子程序==================
SetTime		PROC	NEAR
		LEA		SI,bufferTimeSetting	;之前时间信息放到设置缓存里，以便显示
		CALL 	TimeToBuffer			
		MOV		TimePos,0		;将时间位标志置0，设置时间的第0位，时的十位数
Key:	CMP	timeSettingFlash,1		;判断是否需要闪烁当前位  
		JNZ	GetKey							;扫描键盘
		LEA	SI,bufferTimeSetting	
		LEA	DI,bufferTime
		MOV	CX,8					;重复8次
		REP	MOVSB
		CMP	halfsec,0
		JNZ	Flash
		MOV	BL,TimePos
		NOT	BL
		AND	BX,07H
		LEA	SI,bufferTime
		MOV	BYTE PTR [SI+BX],10H	;当前设置位置产生闪烁效果
Flash:LEA	SI,bufferTime
		CALL Display8
		MOV	timeSettingFlash,0
GetKey:CALL GetKeyA
		JNB	Key
		CMP	AL,0EH			;放弃设置
		JNZ	EarlyConfirm
		JMP	SetTimeExit
EarlyConfirm:CMP AL,0FH		;判断设置时间时是否按下F键，若按下F键，提前确认设置	
		JZ	SettedTimeToVariable
SetTime_hour_High:CMP AL,10			;数值范围为0~9
		JNB	Key					;无效按键
		CMP	TimePos,0
		JNZ	SetTime_hour_Low
		CMP	AL,3					;调整时的十位数（范围为0~2）
		JNB	Key
		MOV	bufferTimeSetting + 7,AL
		JMP	SetTimeIsFinished
SetTime_hour_Low:CMP TimePos,1		;时的个位
		JNZ	SetTime_min_High
		CMP	bufferTimeSetting + 7,2		;判断时的十位是否为2，然后，调整时的个位(当时的十位为0和1时,
		JB	SetTime_hour_Low_1											;其个位范围为0~9，当时为2时，个位范围为0~3)
		CMP	AL,4									;当时的十位为2，判断个位是否小于4（0~3）
		JNB	Key									;若大于3则跳至Key，无效按键
SetTime_hour_Low_1:MOV bufferTimeSetting + 6,AL  ;时的个位数
		INC	TimePos							;TimePos=2，这是个横杠“-”，跳过不用设置这位
		JMP	SetTimeIsFinished
SetTime_min_High:CMP TimePos,3 	;分的十位数
		JNZ	SetTime_min_Low
		CMP	AL,6									;调整分的十位数（范围为0~5）
		JNB	Key									;若大于5则跳至Key，无效按键
		MOV	bufferTimeSetting + 4,AL
		JMP	SetTimeIsFinished	
SetTime_min_Low:CMP TimePos,4			;分的个位数
		JNZ	SetTime_sec_High
		MOV	bufferTimeSetting + 3,AL		;调整分的个位数（范围为0~9）
		INC	TimePos								;TimePos=5，这是个横杠“-”，跳过不用设置这位
		JMP	SetTimeIsFinished
SetTime_sec_High:CMP	TimePos,6		;秒的十位数
  		JNZ	SetTime_sec_Low
		CMP	AL,6									;调整秒的十位数（范围为0~5）
		JB	SetTime4_sec_High_1
		JMP	Key							;若大于5则跳至Key，无效按键		
SetTime4_sec_High_1:MOV bufferTimeSetting + 1,AL
					JMP	SetTimeIsFinished
SetTime_sec_Low:MOV	bufferTimeSetting,AL		;调整秒的个位数（范围为0~9）
SetTimeIsFinished:INC	TimePos
		CMP	TimePos,8					;判断是否设置完(是否时间位标志=8)，设置完跳转SettedTimeToVariable同步信息
		JNB	SettedTimeToVariable
		MOV	timeSettingFlash,1		;需要刷新
		JMP	Key		
SettedTimeToVariable:MOV AL,bufferTimeSetting + 1		;设置的时间转换到变量中；同步信息
		MOV	BL,10
		MUL	BL
		ADD	AL,bufferTimeSetting
		MOV	sec,AL			;秒
		MOV	AL,bufferTimeSetting + 4
		MUL	BL
		ADD	AL,bufferTimeSetting + 3
		MOV	min,AL			;分
		MOV	AL,bufferTimeSetting + 7
		MUL	BL
		ADD	AL,bufferTimeSetting + 6
		MOV	hour,AL			;时
		CMP	hour,24			;以下程序是实现避免非法显示功能的,将当前小时数和24比较，若hour<24则跳至SetTimeExit,否则将hour-=24      
		JB	SetTimeExit
		SUB	hour,24			;当前小时数hour大于了24，将hour-=24
SetTimeExit:	RET
SetTime		ENDP

;========================日期设定========================
SetDate		PROC	NEAR
		LEA		SI,bufferDateSetting
		CALL	DateToBuffer
		MOV		DatePos,0		
Key_Date:CMP	dateSettingFlash,1				;判断是否需要闪烁当前位
		JNZ		Date_GetKey
		LEA	SI,bufferDateSetting    		;将bufferDateSetting中的数据存SI中
		LEA	DI,bufferDate
		MOV	CX,8
		REP	MOVSB         					;将bufferDateSetting中的数据拷贝到bufferDate中
		CMP	halfsec,0
		JNZ	FLASH1
		MOV	BL,DatePos
		NOT	BL            			;BL = 1111H
		AND	BX,07H        		;BX = 07H
		LEA	SI,bufferDate    			;将bufferDate的偏移地址存入SI中
		MOV	BYTE PTR [SI+BX],10H	;当前设置位置产生闪烁效果
FLASH1:LEA	SI,bufferDate		
		CALL DisPlay8						;显示日期
		MOV	dateSettingFlash,0
Date_GetKey:CALL GetKeyA   	 	;扫描键盘
		JNB	Key_Date              	;若无按键则跳转
		CMP	AL,0EH				;放弃设置
		JNZ	KeyIsF				;若按的不是E则跳至KeyIsF，判断是否按下F键            
		JMP	SetDateExit          		;按E放弃设置，退出返回
KeyIsF:CMP	AL,0FH      	;判断设置时间时是否按下F键，若按下F键，提前确认设置
		JNZ	DateKeyNotF        	;按键不为F则继续设定
		JMP	DateBufferToVariable       	;按键为F则确定
DateKeyNotF:CMP AL,10       	;日期按键在10以内
		JNB	Key_Date					;大于等于10的按键则为无效按键
		CMP	DatePos,0       	;是否为第一位
		JNZ	SetDate_y_1
		MOV	bufferDateSetting + 7,AL		;调整年的千位数
		JMP	SetDateIsFinished
SetDate_y_1:	CMP	DatePos,1					;是否为第二位
		JNZ	SetDate_y_2
		MOV	bufferDateSetting + 6,AL		;调整年的百位数
		JMP	SetDateIsFinished
SetDate_y_2:	CMP	DatePos,2
		JNZ	SetDate_y_3
		MOV	bufferDateSetting + 5,AL		;调整年的十位数
		JMP	SetDateIsFinished
SetDate_y_3:	CMP	DatePos,3
		JNZ	JudgeLeap
		MOV	bufferDateSetting + 4,AL		;调整年的个位数
		JMP	SetDateIsFinished
JudgeLeap:CALL JudgeLeapYear 			;判断是否为闰年		
		CMP	DatePos,4
		JNZ	SetDate4_1
		CMP	AL,2
		JB	SetDate_m_0
		JMP Key_Date			;无效按键(月的十位大于了1)
SetDate_m_0:MOV	bufferDateSetting + 3,AL		;调整月的十位数
		JMP	SetDateIsFinished
SetDate4_1:CMP DatePos,5
		JNZ	SetDate5
		CMP	bufferDateSetting + 3,0		;调整月的个位数
		JZ	SetDate4_2							;月的十位是0则跳转
		CMP	AL,3
		JB	SetDate_m_1
		JMP Key_Date			;无效按键
SetDate4_2:	CMP	AL,0
		JA	SetDate_m_1
		JMP Key_Date
SetDate_m_1:MOV	bufferDateSetting + 2,AL		;月的个位数
		JMP	SetDateIsFinished 
SetDate5:	CALL    JudgeMonthIs30day   	;判断是否为天数为30天的月份
		PUSH    AX
		MOV     AL,bufferDateSetting + 3
		MOV		BL,10
		MUL     BL
		ADD     AL,bufferDateSetting + 2    	;将当前月份记入AL中
		MOV     month,AL          	;将AL存入month中
		POP	AX
		CMP	DatePos,6
		JNZ	SetDate6
		CMP     month,2         	;是否为2月
		JNZ     SetDate5_0		;不是2月则跳转
		CMP     AL,3
		JB	SetDate5_2
		JMP     Key_Date
SetDate5_2:	JMP     SetDate_d_0
SetDate5_0:	CMP 	AL,4			;调整日的十位数 (判断日十位数是否<=3)
		JB	SetDate_d_0				
		JMP	Key_Date					;无效按键
SetDate_d_0:MOV	bufferDateSetting + 1,AL
		JMP	SetDateIsFinished
SetDate6:	CMP	DatePos,7
		JNZ	DateBufferToVariable
		CMP month,2			;判断是否为2月
        JNZ SetDate6_0		;不是2月则跳转
		CMP	LeapYear,0			;是2月，判断是否为闰年
		JZ	SetDate6_2				;不是闰跳转
		JMP	SetDate_d_1			;是闰年
SetDate6_2:	CMP	AL,9			;当前是2月份以及不是闰年的情况下，判断日的个位数是否小于9
		JB	SetDate_d_1
		JMP	Key_Date
SetDate6_0: 	CMP 	bufferDateSetting + 1 ,3		;判断日的十位是否为3
		JNZ	SetDate_d_1		;不是3跳转
		CMP	MonthHas30Day,0		;是3，判断是否为小月
		JZ	SetDate6_3		;不是小月则跳转
		CMP	AL,1
		JB	SetDate_d_1
		JMP	Key_Date
SetDate6_3:	CMP	AL,2
		JB	SetDate_d_1
		JMP	Key_Date			
SetDate_d_1: 	MOV	bufferDateSetting,AL		;调整日的个位数
SetDateIsFinished:	INC	DatePos
		CMP	DatePos,8
		JNB	DateBufferToVariable       	 	;大于等于第8位则确定
		MOV	dateSettingFlash,1		;8位没设定完则继续，日期需要刷新
		JMP	Key_Date		
DateBufferToVariable:MOV AL,bufferDateSetting + 1		;确认
		MOV	BL,10
		MUL	BL
		ADD	AL,bufferDateSetting
		MOV	day,AL			;日
		MOV	AL,bufferDateSetting + 3
		MUL	BL
		ADD	AL,bufferDateSetting + 2
		MOV	month,AL		;月
		MOV	AL,bufferDateSetting + 5	
		MUL	BL
		ADD	AL,bufferDateSetting + 4	
		MOV	yearLowPos2,AL
		MOV	AL,bufferDateSetting + 7
		MUL	BL
		ADD	AL,bufferDateSetting + 6
		MOV	yearHighPos2,AL
		CALL	JudgeLeapYear
		CMP	month,13
		JB	SetDate8_0		;以下程序是实现避免非法显示功能的
		SUB	month,12			;月数大于12则month-=12
SetDate8_0:	CMP	month,2
		JNZ	SetDate8_1
		CMP	LeapYear,1
		JZ	SetDate8_3
		CMP	day,28
		JNA	SetDateExit
		SUB	day,28
		JMP	SetDateExit
SetDate8_1:	CALL JudgeMonthIs30day
		CMP	MonthHas30Day,1
		JNZ	SetDate8_2
		CMP	day,30
		JNA	SetDateExit
		SUB	day,30
		JMP	SetDateExit
SetDate8_2:	CMP	day,31
		JNA	SetDateExit
		SUB	day,31
		JMP	SetDateExit
SetDate8_3:	CMP	day,29
		JNA	SetDateExit
		SUB	day,29
		JMP	SetDateExit
SetDateExit:		RET
SetDate		ENDP

;========================是否为闰年========================
JudgeLeapYear	PROC	NEAR
                PUSH    AX
                PUSH    BX
                PUSH    DX
                LEA     SI,bufferDateSetting
                MOV     AL,bufferDateSetting + 7      	;年的千位数
                XOR		AH,AH
                MOV     BL,10               
                MUL     BL                  	;年的千位数*10
                ADD     AL,bufferDateSetting + 6      	;年的千位数*10+年的百位数
                MUL     BL                  	;(年的千位数*10+年的百位数)*10
                ADD     AL,bufferDateSetting + 5      	;(年的千位数*10+年的百位数)*10+年的十位数
                MUL     BL                  	;[(年的千位数*10+年的百位数)*10+年的十位数]*10
                ADD     AL,bufferDateSetting + 4      	;[(年的千位数*10+年的百位数)*10+年的十位数]*10+年的各位位数
                MOV     year,AX
                XOR     DX,DX 
                MOV     BX,400
                DIV     BX
                CMP     DX,0               	;能整除DX＝0
                JZ      JudgeLeapYear2      	;能被400整除为闰年
                
                MOV     AX,year 
                XOR     DX,DX
                MOV     BX,4
                DIV     BX
                CMP     DX,0
                JZ      JudgeLeapYear1      	;能被4整除则跳转
                JMP     JudgeLeapYear3
JudgeLeapYear1:  MOV     AX,year 
                XOR     DX,DX
                MOV     BX,100
                DIV     BX
                CMP     DX,0
                JZ      JudgeLeapYear3       	;能被100整除则跳转    
JudgeLeapYear2:  MOV     LeapYear,1       	;能被4整除不能被100整除为闰年
		JMP	PopT

JudgeLeapYear3:  MOV     LeapYear,0       	;不能被4整除不是闰年
                                           	;能被4整除且能被100整除的不是闰年
PopT:		POP	DX
		POP	BX
		POP	AX
		RET          
JudgeLeapYear	ENDP

;====================是否为天数为30天的月份====================
;=======================4月6月9月11月=========================
JudgeMonthIs30day	PROC	NEAR
		PUSH 	AX
   		PUSH	BX
    		MOV	AL,bufferDateSetting + 3
    		MOV	BL,10
    		MUL	BL
    		ADD	AL,bufferDateSetting + 2
    		CMP	AX,4
    		JZ	Here
    		CMP	AX,6
    		JZ	Here
    		CMP	AX,9
    		JZ	Here
    		CMP	AX,11
    		JZ	Here
    		MOV	MonthHas30Day,0
    		JMP	Pop1
Here:		MOV	MonthHas30Day,1
Pop1:   	POP	BX
 		POP	AX
 		RET	
JudgeMonthIs30day	ENDP

;========================显示时分秒========================
Display_LED_Time	PROC	NEAR
		LEA	SI,bufferTime
		CALL	TimeToBuffer
		LEA	SI,bufferTime
		CALL	Display8		;显示
		RET
Display_LED_Time	ENDP

;显示年月日
Display_LED_Date	PROC	NEAR
		LEA	SI,bufferDate
		CALL	DateToBuffer
		LEA	SI,bufferDate
		;CALL	Display8_1		;显示
		CALL DisPlay8
		RET
Display_LED_Date	ENDP		

;==============hour min sec转化成可显示格式=================
TimeToBuffer	PROC	NEAR
		MOV	AL,sec
		XOR	AH,AH
		MOV	BL,10
		DIV	BL
		MOV	[SI],AH
		MOV	[SI + 1],AL		;秒
		
		MOV	BYTE PTR [SI + 2],10H	;不显示

		MOV	AL,min
		XOR	AH,AH
		DIV	BL
		MOV	[SI + 3],AH		
		MOV	[SI + 4],AL		;分
	
		MOV	BYTE PTR [SI + 5],10H	;这位不显示

		MOV	AL,hour
		XOR	AH,AH
		DIV	BL
		MOV	[SI + 6],AH		
		MOV	[SI + 7],AL		;时
		RET
TimeToBuffer	ENDP

;==============day month year转换为可显示格式==============
DateToBuffer	PROC	NEAR
		MOV	AL,day
		XOR	AH,AH
		MOV	BL,10
		DIV	BL
		MOV	[SI],AH			;余数为日的个位
		MOV	[SI + 1],AL		;商为日的十位

		MOV	AL,month
		XOR	AH,AH
		DIV	BL
		MOV	[SI + 2],AH		;余数为月的个位
		MOV	[SI + 3],AL		;商为月的十位

		MOV	AL,yearLowPos2
		XOR	AH,AH
		DIV	BL
		MOV	[SI + 4],AH		;余数为年的个位
		MOV	[SI + 5],AL		;商为年的十位
		
		MOV	AL,yearHighPos2
		XOR	AH,AH
		DIV	BL
		MOV	[SI + 6],AH		;余数为年的百位
		MOV	[SI + 7],AL		;商为年的千位
		RET
DateToBuffer	ENDP

;========================0.5s产生一次中断========================
CalendarInt 	PROC	NEAR
		PUSH	AX
		PUSH	DX
		MOV	timeSettingFlash,1		;时间是否需要刷新
		MOV	dateSettingFlash,1		;日期是否需要刷新
		INC	halfsec
		CMP	halfsec,2
		JZ	CalendarInt7
		JMP	CalendarInt1
CalendarInt7:	MOV	timeNeedFlashDisp,1
		MOV	dateNeedFlashDisp,1
		MOV	halfsec,0
		INC	sec
		CMP	sec,60                 
		JZ	CalendarInt8            ;秒满60则跳转
		JMP	CalendarInt1             
CalendarInt8:	MOV	sec,0           ;当秒为60时将秒置为0
		INC	min                     ;给分加1
		CMP	min,60
		JZ	CalendarInt9            ;分满60则跳转
		JMP	CalendarInt1            
CalendarInt9:	MOV	min,0           ;当分为60时将分置为0
		INC	hour                    ;给时加1
		CMP	hour,24
		JNZ	CalendarInt1
		MOV	hour,0                  ;当时满24时将时置为0
		INC	day                     ;给天加1

CalendarInt2:	CMP	month,2			;是否为2月
		JNZ     CalendarInt3		;不是2月则跳转
		CMP	LeapYear,1		;是否为闰年（0为否，1为是）
		JNZ	CalendarInt5		;不是闰年则跳转
		CMP	day,30			;是闰年
		JNZ	CalendarInt1
		JMP	CalendarInt6 
		
CalendarInt5:	CMP	day,29
		JNZ	CalendarInt1
		JMP	CalendarInt6
      
CalendarInt3:	CMP	MonthHas30Day,0 	;是否为天数为30天的月份（0为否，1为是）
		JNZ	CalendarInt4		;是小月则跳转
		CMP	day,32			;不是小月
		JNZ	CalendarInt1
		JMP	CalendarInt6  
		
CalendarInt4:	CMP	day,31
		JNZ	CalendarInt1  
		
CalendarInt6:	MOV	day,1
		INC month
		CMP	month,13
		JNZ	CalendarInt1
		MOV	month,1
		INC yearLowPos2
		CMP	yearLowPos2,100
		JNZ	CalendarInt1
		MOV	yearLowPos2,0
		INC	yearHighPos2  
		
CalendarInt1:
		
		LEA		SI,bufferTime
		CALL	DateToBuffer		
		CALL	SHOWCALENDER		;在液晶显示器上显示年月日
		LEA		SI,bufferDate
		CALL	TimeToBuffer
		CALL	SHOWTIME			;在液晶显示器上显示时分秒
		
		MOV	DX,IO8259_0
		MOV	AL,20H
		OUT	DX,AL
		POP	DX
		POP	AX
		IRET
CalendarInt ENDP
			
;========================8253初始化========================
Init8253	PROC	NEAR
		MOV     DX,Con_8253		;送控制寄存器端口地址给DX
	        MOV     AL,34H			;00110100b 选择计数器0，先读写低字节，再读写高字节,方式2，二进制计数
        	OUT     DX,AL			;计数器T0设置在模式2状态,HEX计数
	        MOV     DX,T0_8253
	        MOV     AL,12H			;设置计数初值 
	        OUT     DX,AL			;写计数值的低8位
	        MOV     AL,7AH			;计数值的高8位
	        OUT     DX,AL			;CLK0=62.5kHz,0.5s定时
		RET
Init8253	ENDP

;========================8259初始化========================
Init8259	PROC	NEAR
		MOV	DX,IO8259_0
		MOV	AL,13H			;中断类型号，设定边沿触发，单片方式
		OUT	DX,AL
		MOV	DX,IO8259_1
		MOV	AL,08H			;中断类型号，设定IRQ0的中断向量号位08H(中断源：电子钟时间基准)
		OUT	DX,AL
		MOV	AL,09H			;中断类型号，中断源：键盘
		OUT	DX,AL
		MOV	AL,0FEH
		OUT	DX,AL
		RET
Init8259	ENDP

;========================设置中断向量========================
WriIntver	PROC	NEAR
		PUSH	ES
		MOV	AX,0
		MOV	ES,AX
		MOV	DI,20H
		LEA	AX,CalendarInt
		STOSW
		MOV	AX,CS
		STOSW
		POP	ES
		RET
WriIntver	ENDP
  
;==============数据写入8279数据端口==============
WRITE_DATA      PROC    NEAR
        	MOV     DX,DATA_8279
        	OUT     DX,AL
        	RET
WRITE_DATA      ENDP

;------------------------------------以下是液晶显示屏相关-----------------------------------------

;液晶显示年月日的具体实现
SHOWCALENDER PROC NEAR
 R0:		LEA SI,ZERO
		MOV AH,00
		MOV AL,	bufferTime
		MOV BL,16
		MUL BL
		ADD SI,AX
		   
               		mov al,2
               		mov ah,24
               		call byteDISR

R1:		LEA SI,ZERO
		MOV AH,00
		MOV AL,	bufferTime+1
		MOV BL,16
		MUL BL
		ADD SI,AX
		   
               		mov al,2
               		mov ah,16
               		call byteDISR

R2:		LEA SI,ZERO
		MOV AH,00
		MOV AL,	bufferTime+2
		MOV BL,16
		MUL BL
		ADD SI,AX

		mov al,2
               		mov ah,8
               		call byteDISR

R3:		LEA SI,ZERO
		MOV AH,00
		MOV AL,	bufferTime+3
		MOV BL,16
		MUL BL
		ADD SI,AX
		   
               		mov al,2
               		mov ah,0
               		call byteDISR

R4:		LEA SI,ZERO
		MOV AH,00
		MOV AL,	bufferTime+4
		MOV BL,16
		MUL BL
		ADD SI,AX
		   
               		mov al,2
               		mov ah,56
               		call byteDISL

R5:		LEA SI,ZERO
		MOV AH,00
		MOV AL,	bufferTime+5
		MOV BL,16
		MUL BL
		ADD SI,AX
		   
               		mov al,2
               		mov ah,48
               		call byteDISL

R6:		LEA SI,ZERO
		MOV AH,00
		MOV AL,	bufferTime+6
		MOV BL,16
		MUL BL
		ADD SI,AX
		   
               		mov al,2
               		mov ah,40
               		call byteDISL
R7:		LEA SI,ZERO
		MOV AH,00
		MOV AL,	bufferTime+7
		MOV BL,16
		MUL BL
		ADD SI,AX
		   
               		mov al,2
               		mov ah,32
               		call byteDISL
		RET
SHOWCALENDER ENDP
;液晶显示时分秒的具体实现
SHOWTIME	 PROC NEAR
 A0:		LEA SI,ZERO
		MOV AH,00
		MOV AL,	bufferDate
		MOV BL,16
		MUL BL
		ADD SI,AX		   
               	mov al,4
               	mov ah,24
               	call byteDISR
A1:		LEA SI,ZERO
		MOV AH,00
		MOV AL,	bufferDate+1
		MOV BL,16
		MUL BL
		ADD SI,AX		   
               	mov al,4
               	mov ah,16
               	call byteDISR
AP:		LEA SI,POINT
		mov al,4
		mov ah,8
		call byteDISR	
A2:		LEA SI,ZERO
		MOV AH,00
		MOV AL,	bufferDate+3
		MOV BL,16
		MUL BL
		ADD SI,AX		   
               	mov al,4
               	mov ah,0
               	call byteDISR
A3:		LEA SI,ZERO
		MOV AH,00
		MOV AL,	bufferDate+4
		MOV BL,16
		MUL BL
		ADD SI,AX		   
               	mov al,4
               	mov ah,56
               	call byteDISL
APOINT:		LEA SI,POINT
		mov al,4
		mov ah,48
		call byteDISL
A4:		LEA SI,ZERO
		MOV AH,00
		MOV AL,	bufferDate+6
		MOV BL,16
		MUL BL
		ADD SI,AX		   
               	mov al,4
               	mov ah,40
               	call byteDISL
A5:		LEA SI,ZERO
		MOV AH,00
		MOV AL,	bufferDate+7
		MOV BL,16
		MUL BL
		ADD SI,AX		   
               	mov al,4
               	mov ah,32
               	call byteDISL
	RET
SHOWTIME	 ENDP

;延时程序
; DelayTime	PROC	NEAR
		; MOV	CX,0
		; LOOP	$
		; LOOP	$
		; RET
; DelayTime	ENDP
		
;液晶初始化
LCD_INIT	PROC	NEAR	
	MOV	AL,3EH	;初始化左半屏，关显示
	CALL		WRComL	;写指令子程序
	MOV	AL,FirstLine	;设置起始显示行，第0行
	CALL	WRComL	
	MOV	AL,3EH	;初始化右半屏，关显示
	CALL	WRComR	;写指令子程序
	MOV		AL,FirstLine	;设置起始显示行，第0行
	CALL	WRComR	
	;CALL	LCDClear	;清屏
	MOV	AL,3FH	;开显示
	CALL	WRComL	
	MOV	AL,3FH	;开显示
	CALL		WRComR	
	RET		
LCD_INIT		ENDP		
;清屏
LCDClear	PROC		NEAR	
;清左半屏
	MOV	AL,0	;起始行，第0行
	MOV	AH,0		;起始列，第0列
LCDClearL1:	PUSH		AX	
	MOV		CX,64	
	CALL		SETXYL	;设置起始显示行列地址
LCDClearL2:	MOV	AL,0	
	CALL	WRDATAL	
	LOOP	LCDClearL2	
	POP	AX	
	INC	AX	
	CMP	AL,8	;共8行
	JNZ	LCDClearL1	
;清右半屏
	MOV		AL,0		;起始行，第0行
	MOV	AH,0		;起始列，第0列
LCDClearR1:	PUSH		AX	
	MOV		CX,64	
	CALL	SETXYR	;设置起始显示行列地址
LCDClearR2:	XOR	AL,AL	
	CALL	WRDATAR	
	LOOP	LCDClearR2	
	POP	AX	
	INC		AL	
	CMP	AL,8		;共8行
	JNZ	LCDClearR1	
	RET		
LCDClear	ENDP		
;显示字体，显示一个数据要占用X行两行位置
;左半屏显示一个字节/字：AL-起始显示行序数X(0-7)；AH-起始显示列序数Y(0-63)；SI-显示字
数据首地址
ByteDisL		PROC	NEAR	
	MOV		CX,8      ;显示8个字节数据，用于显示一个英文/符号
	CALL		DispL	
	RET		
ByteDisL	ENDP		
WordDisL	PROC	NEAR	
	MOV	CX,16	;显示16字节数据，用于显示一个汉字
	CALL	DispL	
	RET		
WordDisL	ENDP		
DispL	PROC	NEAR	
	PUSH	AX	
	PUSH		CX	
	CALL	SETXYL	;设置起始显示行列地址
	CALL	DisplayL	;显示上半行数据
	POP	CX	
	POP	AX	
	INC	AL	
	CALL	SETXYL	;设置起始显示行列地址
	CALL		DisplayL		;显示下半行数据
	RET			
DispL	ENDP		
;右半屏显示一个字节/字：AL-起始显示行序数X(0-7)；AH-起始显示列序数Y(0-63)；SI-显示字数据首地址
ByteDisR		PROC	ENAR	
	MOV	CX,8       ;显示8个字节数据，用于显示一个英文/符号
	CALL	DispR	
	RET		
ByteDisR	ENDP		
WordDisR	PROC	NEAR	
	MOV	CX,16	;显示16字节数据，用于显示一个汉字
	CALL	DispR	
	RET		
WordDisR	ENDP		
DispR	PROC		NEAR	
	PUSH		AX	
	PUSH		CX	
	CALL		SETXYR	;设置起始显示行列地址
	CALL		DisplayR		;显示上半行数据
	POP	CX	
	POP	AX	
	INC	AL	
	CALL	SETXYR	;设置起始显示行列地址
	CALL	DisplayR	;显示下半行数据
	RET		
DispR	ENDP		
;显示图形	
;显示左半屏一行图形,AL-X起始行序数(0-7)，AH-Y起始列地址序数(0-63)
LineDisL	PROC	NEAR	
	MOV		CX,64	
	CALL	SETXYL	;设置起始显示行列
	CALL	DisplayL		;显示数据
	RET 		
LineDisL	ENDP		
;显示右半屏一行图形,AL-X起始行地址序数(0-7)，AH-Y起始列地址序数(0-63)
LineDisR	PROC	NEAR	
	MOV	CX,64	
	CALL	SETXYR	;设置起始显示行列
	CALL	DisplayR	;显示数据
	RET			
LineDisR	ENDP		
;基本控制
;显示左半屏数据，R7-显示数据个数
DisplayL		PROC		NEAR	
	LODSB		
	CALL		WRDataL	;写左半屏数据
	LOOP	DisplayL	
	RET		
DisplayL	ENDP		
;显示右半屏数据，R7-显示数据个数
DisplayR	PROC		NEAR	
	LODSB		
	CALL		WRDataR	;写左半屏数据
	LOOP	DisplayR	
	RET		
DisplayR	ENDP		
;设置左半屏起始显示行列地址,AL-X起始行序数(0-7)，AH-Y起始列序数(0-63)
SETXYL	PROC	NEAR	
	OR	AL,X		;行地址=行序数+行基址
	CALL	WRComL	
	MOV	AL,AH	
	OR	AL,Y		;列地址=列序数+列基址
	CALL		WRComL	
	RET		
SETXYL	ENDP		
;设置右半屏起始显示行列地址,AL-X起始行序数(0-7)，AH-Y起始列序数(0-63)
SETXYR	PROC	NEAR	
	OR	AL,X		;行地址=行序数+行基址
	CALL		WRComR	
	MOV	AL,AH	
	OR	AL,Y		;列地址=列序数+列基址
	CALL	WRComR	
	RET		
SETXYR	ENDP		
;写左半屏控制指令，A-写入指令
WRComL	PROC		NEAR	
	MOV	DX,WR_COM_AD_L	
	OUT		DX,AL	
WRComL1:	MOV	DX,RD_BUSY_AD	
	IN	AL,DX	
	TEST	AL,80H	;检查液晶显示是否处于忙状态
	JNZ	WRComL1	
	RET		
WRComL	ENDP		
;写右半屏控制指令，A-写入指令
WRComR		PROC		NEAR	
	MOV	DX,WR_COM_AD_R	
	OUT	DX,AL	
WRComR1:	MOV	DX,RD_BUSY_AD	
	IN	AL,DX	
	TEST		AL,80H	;检查液晶显示是否处于忙状态
	JNZ	WRComR1	
	RET		
WRComR	ENDP		
;写左半屏数据，A-写入数据	
WRDataL	PROC		NEAR	
	MOV	DX,WR_DATA_AD_L	
	OUT		DX,AL	
WRDataL1:	MOV	DX,RD_BUSY_AD	
	IN	AL,DX	
	TEST		AL,80H	;检查液晶显示是否处于忙状态
	JNZ	WRDataL1	
	RET		
WRDataL	ENDP		
;写右半屏数据，A-写入数据	
WRDataR	PROC		NEAR	
	MOV		DX,WR_DATA_AD_R	
	OUT	DX,AL	
WRDataR1:	MOV	DX,RD_BUSY_AD	
	IN	AL,DX	
	TEST		AL,80H		;检查液晶显示是否处于忙状态
	JNZ	WRDataR1	
	RET		
WRDataR	ENDP

		END	START

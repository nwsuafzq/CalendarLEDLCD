# CalendarLEDLCD
数码管日历表，包括显示器显示

```
;连线说明
;E5区 ：CLK(8279)   ————  B2区：2M
;E5区 ：CS(8279)、A0     ————  A3区：CS5、A0
;E5区 ：A、B、C、D(8279)  ————   G5区：A、B、C、D
;B3区 ：CS(8259)、A0     ————  A3区：CS1、A0
;B3区：INT、INTA          ———— ES8688：INTR、INTA
;B3区：IR0              ————  C5区 ：OUT0
;C5区 ：CS（8253）、A0、A1————    A3区：CS2、A0、A1
;C5区 ：GATE0           ————  C1区：VCC
;C5区 ：CLK0            ————  B2区：62.5K
;A1区：CS、RW、RS、CS1/2             A3区：CS4、A0、A1、A2
```

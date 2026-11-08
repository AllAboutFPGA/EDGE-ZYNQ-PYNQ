@echo off
rem Run the edge_pwm testbench in the Vivado simulator. Expect "TEST PASSED".
if "%VIVADO%"=="" set VIVADO=E:\Xilinx\Vivado\2022.2
cd /d %~dp0
call "%VIVADO%\bin\xvlog.bat" ..\hdl\edge_pwm.v || exit /b 1
call "%VIVADO%\bin\xvlog.bat" -sv tb_edge_pwm.sv || exit /b 1
call "%VIVADO%\bin\xelab.bat" tb_edge_pwm -s tb_edge_pwm || exit /b 1
call "%VIVADO%\bin\xsim.bat" tb_edge_pwm -R

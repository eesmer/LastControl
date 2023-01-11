## LastControl-Handbook / User Guide
This document contains the process subject and details in linux systems for process management.<br>

---
### -Process_Management
---

**Program** is a term for source code or files that can be run. When a program is run, it is now called a process.<br>
<br>
When a program is running in a Linux environment, it is called a process. Linux systems monitor and follow the programs with the "Process Control Block".<br>
For a process, the following states can be followed instantly in the system.<br>
- Status
- Memory usage
- The files it uses
- working directory
<br>

Linux systems when the programs run and process status, allocate resources for these running processes and follow them and this resource is taken back when the process is terminated.<br>
For these main reasons;<br>
Process management in Linux systems is a very important issue and is directly related to the stable and healthy operation of the system.<br>
Performance of the system depends of process states.<br>
<br>

#### Process ID
Each process has a unique ID value. Linux systems will never be reassigned to the same ID at the same time.<br>
There is of course a limit for this ID number.<br>
(If this limit is filled, the system becomes unstable. But this limit is unlikely to be filled under normal conditions.<br>
The state that fills the limit will cause many other problems before it fills the ID limit)<br>
<br>
We can learn the maximum process value of the system with the following command.<br>
```sh
$ cat /proc/sys/kernel/pid_max
```
<br>
Process ID numbers are given in ascending order for running programs.<br>
The first Process ID comes from the boot process and gets the number "0". (swap process)<br>
When the operating system is loaded, the process that receives the "1" ID number starts to run on the system. (init process)<br>
In the operating system, all processes after this step start to work by increasing according to the process number "1".<br>
The boot process with ID "0" creates an init process with ID "1". All subsequent processes consist of init process.<br>


#### Parent Process - Child Process
In Linux systems, there is a parent-child relationship between processes.<br>
After the process occurs, related child processes also occur.<br>
The first process is the main process and all other processes are child processes. (forked process)<br>
<br>
The system process list is retrieved with the **ps** command.
```sh
$ ps
```
parameters;<br>
```sh
A: all processes
e: all processes
x: process list of current user
f: details process list table
u: user firiendly process list table
--forest tree view
```
<br>
fields of process list table<br>
PID: Process ID<br>
TTY: Users terminal<br>
STAT: Process State Code<br>
TIME: The time the process is running<br>
CMD: Then command that starts the process<br>
<br>

### Management of Process
For process list and running process information, **ps**, **top** and **htop** commands are sufficient for all viewing/listing needs.<br>
```sh
$ ps
```
It works as a snapshot. We get the instant process list with the ps command.<br>
```sh
$ top
```
It runs as a table of process. With the top command, we get a screen output where interactive, statistical and process statuses are updated.<br>
```sh
$ htop
```
It works as a humanly table of process. It is a user-friendly appearance of the top command.<br>
<br>
The state of the processes is very important for the health of the system.<br>
For this reason, the status of the processes and thus the load on the system should be monitored and controlled.<br>
<br>
The load of the system is determined by the processes on the system. We can learn the system load status with the following command.<br>
```sh
$ top -n 1 -b | grep "load average:"
```
<br>
3 columns in the load average header; Shows the system's load status for the last 5, 10 and 15 minutes.<br>
Basically;<br>
The load state of the system should not exceed the number of CPUs.<br>
We find out the CPU count with the following command.<br>

```sh
$ nproc --all
```
The columns in the "load average" header of the top command output above should not exceed the number of CPUs.<br>
We can also do the above basic control interactively with the "htop" command.<br>

#### About of Zombie Process
Processes that continue to remain in the process table even though they receive the system call for exit that completes their work are called zombie processes.<br>
If the parent process does not send a signal to its child process to terminate and does not perform its ongoing operations, the child process will not be able to perform the termination step, so it will remain as a child process but will not perform any operation.<br>
<br>
In this way, processes that are zombies indicate a problematic process status and should be checked and terminated in a healthy way.<br>
<br>
We can search for zombie processes in the system with the following command.<br>

```sh
$ ps -A -ostat,ppid,pid,cmd | grep -e '^[Zz]'
```
As a result;<br>
For the healthy functioning of the system, the number of processes should be processed in accordance with the capacity of the system (cpu, ram, disk), and the start and completion of the process should be done smoothly.

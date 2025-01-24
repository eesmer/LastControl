echo "top 5 cpu consuming processes"
ps -eo pid,comm,%cpu --sort=-%cpu | head -n 6
echo -e


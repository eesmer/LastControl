echo "top 5 cpu consuming processes"
ps -eo pid,comm,%cpu --sort=-%cpu | head -n 6
echo -e

echo top 5 memory consuming process
ps -eo pid,comm,%mem --sort=-%mem | head -n 6
echo -e

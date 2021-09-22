port=`cat ./config/port.txt`
ps=`lsof -i :$port | awk '{print$2}'`
for f in $ps
{
    if [[ "$f" != "PID" ]] ; then
        kill -9 $f
    fi
}

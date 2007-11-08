#
# This is the series of commands einar used to test tha daemon
#

echo queue > testfile;

for f in $(find $DIR -type f);
do
    echo "scan --heurlevel=2 --archive=7 --adware --applications stream $f size $(ls -l $f | cut -d' ' -f6)" >> testfile ; cat $f >> testfile;
    echo >> testfile
done
echo scan >> testfile
cat testfile | netcat localhost 10200

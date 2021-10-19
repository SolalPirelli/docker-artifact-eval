#!/bin/sh

echo 'Table 1...'
./rabia-table-1.sh
printf '\n\n---\n\n'

echo 'Figure 4...'
./rabia-figure-4.sh
printf '\n\n---\n\n'

echo 'Figure 5...'
echo 'Sync-rep...'
./rabia-figure-5-rep.sh
echo ''
echo 'Redis-Rabia...'
./rabia-figure-5-redis.sh
printf '\n\n---\n\n'

echo 'Variable data size...'
./rabia-vd.sh

#!/bin/bash

grep -A3 "Force.*FAILED" log > force_log
grep "Percent" force_log > force_log2

#!/bin/bash

# Copyright 2017 Darius Neatu (neatudarius@gmail.com)

function display_score() {
    status=0

    if [ ! -z "$1" ]; then
        status=$1
    fi

    echo "===================>>>>>> Total: $total/$MAX_POINTS  <<<<<<====================="

    if (( total > 100 )); then
        if (( has_warnings > 0 )); then
            echo "=======>>>>>> Ai fi un boss daca nu ai avea warning-uri! <<<<<<======"
        else
            echo "===================>>>>>>        Ce boss! <<<<<<====================="
        fi
    fi
    exit $status
}

function check_readme() {
    README=README

    echo "---------------------------------------------------------------------"
    echo "---------------------------------------------------------------------"
    echo "---------------------------------------------------------------------"
    echo "---------------------------------------------------------------------"
    echo "========================>>>>>>    $README   <<<<<< ==================="

    score=0
    max_score=4

    if (( $(echo "$total == 0" |bc -l)  )); then
        echo "Punctaj $README neacordat. Punctajul pe teste este $total!"
    elif [ ! -f $README ]; then
        echo "$README lipsa."
    elif [ -f $README ] && [ "`ls -l $README | awk '{print $5}'`" == "0" ]; then
        echo "$README gol."
    else
        score=$max_score
        echo "$README detectat. Punctajul final se va acorda la corectare."
    fi

    total=$(bc <<< "$total + $score")

    echo "========================>>>>>> score: $score/$max_score  <<<<<< ==================="
    printf "\n\n"
}

function check_cs_errors() {
    python cs.py *.h *.c 2> tmp
    cnt_cs=`cat tmp | grep "Total errors found" | cut -d ':' -f2 | cut -d ' ' -f2`
}

function check_coding_style() {
    echo "---------------------------------------------------------------------"
    echo "---------------------------------------------------------------------"
    echo "---------------------------------------------------------------------"
    echo "---------------------------------------------------------------------"
    echo "=====================>>>>>> Coding style <<<<<< ====================="
    max_score=6

    cnt_cs=0
    check_cs_errors
    if (( cnt_cs > 0)); then
        score = 0;
        cat tmp | head -20
    else
        score=$max_score
        echo "Nu au fost detectate erori de coding style in mod automat."
    fi
    rm -f tmp

    total=$(bc <<< "$total + $score")
    echo "Punctajul final pe coding style se va acorda la corectare."
    echo "=====================>>>>>> score: $score/$max_score   <<<<<< ====================="
    printf "\n\n"
}

function check_diff {
    OUT=$1
    REF=$2
    test_score=$3

    if [ -z "$(diff -qwB $OUT $REF)" ]; then
        type_score=$(bc <<< "$type_score + $test_score")
        echo "pass ==> $test_score/$test_score"
    else
        echo "fail ==>           0/$test_score"
        fail "differences found"

        echo "-- First lines of the diff below --"
        diff -uwB $OUT $REF | head -n 10
        echo "-----"
        echo
    fi
}

function test_allocator() {
    echo "---------------------------------------------------------------------"
    echo "---------------------------------------------------------------------"
    echo "---------------------------------------------------------------------"
    echo "---------------------------------------------------------------------"
    echo "------------------------- test type: $test_prefix -----------------------"

    type_score=0
    for i in "${tests[@]}"; do
        IN="$TESTS_DIR"/"$test_prefix"_"$i".in
        OUT="$TESTS_DIR"/"$test_prefix"_"$i".out
        REF="$TESTS_DIR"/"$test_prefix"_"$i".ref

        if [ ! -f "$IN" ]; then
            echo "NU exista $IN!"
            continue
        fi
        rm -f $OUT $REF

        printf "$IN: "

        # Generating the reference output
        $REFERENCE < $IN > $REF

        # Running the program
        # (time timeout $TIMEOUT $ALLOCATOR < $IN > $OUT) &> error
        $ALLOCATOR < $IN > $OUT

        check_diff $OUT $REF ${points[(($i-1))]}
    done

    total=$(bc <<< "$total + $type_score")
    echo "================>>>>>> $test_prefix score : $type_score/$pmax <<<<<< ================"
    printf "\n\n"
}

function generate_random() {
    # Usage:
    # ./generator.py <cmd.in> <output.out> <min_arena> <max_arena> <min_op> <max_op>
    min_arena=( 50   100   2000  3000   5000  500000)
    max_arena=(100   200   3000  4000  10000 1000000)
    min_op=(    10    50    100   200   1000      10)
    max_op=(    50   100    200   300   2000      50)

    for i in "${tests[@]}"; do
        IN="$TESTS_DIR"/"$test_prefix"_"$i".in
        REF="$TESTS_DIR"/"$test_prefix"_"$i".ref

        MIN_ARENA=${min_arena[(($i - 1))]}
        MAX_ARENA=${max_arena[(($i - 1))]}
        MIN_OP=${min_op[(($i - 1))]}
        MAX_OP=${max_op[(($i - 1))]}

        $GENERATOR $IN $REF $MIN_ARENA $MAX_ARENA $MIN_OP $MAX_OP
    done
}

function test_basic() {
    test_prefix=basic
    tests=(1 2 3)
    points=(5 5 5)
    pmax=15

    test_allocator
}

function test_advanced() {
    test_prefix=advanced
    tests=(1 2 3)
    points=(10 10 10)
    pmax=30

    test_allocator
}

function test_random() {
    test_prefix=random
    tests=(1 2 3 4 5 6)
    points=(5 5 5 10 10 10)
    pmax=45

    generate_random
    test_allocator
}

function test_bonus() {
    ls | grep bonus > /dev/null
    if [ "$?" -ne "0" ]; then
        echo "NO \"bonus\" file found. Skip checking bonus..."
        return
    fi

    test_prefix=bonus
    tests=(1 2 3)
    points=(5 5 10)
    pmax=20

    test_allocator
}

# Test entire project
function test_project() {
    test_basic
    test_advanced
    test_random
    test_bonus
}

total=0
MAX_POINTS=100
TESTS_DIR=_tests
TIMEOUT=10
ALLOCATOR="./allocator"
REFERENCE="./reference"
GENERATOR="./generator.py"

echo "Check compiler version: "
gcc --version &> tmp; cat tmp | head -1
python --version
printf "\n"

# Check if Makefile exists
if [ ! -f Makefile ]; then
    echo "Makefile lipsa. STOP"
    display_score 1
fi

# Compile and check errors
make -f Makefile build &> out.make

cnt=$(cat out.make| grep failed | wc -l)

if [ $cnt -gt 0 ]; then
    echo "Erori de compilare. Verifica versiunea compilatorului. STOP"
    rm -f out.make
    display_score 1
fi

cnt=$(cat out.make | grep warning | wc -l)
has_warnings=0
if [ $cnt -gt 0 ]; then
    echo "Ai warning-uri la compilare. Rusine!"
    has_warnings=1

    cat out.make

    printf "\n"
fi
rm -f out.make

# Display tests set
echo "------------------------------ Run tests ----------------------------"

# Run tests
test_project

check_readme
check_coding_style

# Display result
display_score


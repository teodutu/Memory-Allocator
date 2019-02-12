#!/usr/bin/python

# Computer Programming - Memory Allocation Simulation
# (C) 2008 Stefan Bucur

# This file is used to generate multiple random memory allocation requests

# Usage:
# ./generator.py <cmd.in> <output.out> <min_arena> <max_arena> <min_op> <max_op>


import os
import random
import sys

# Generator constants
ALLOCATOR = "./reference"

# Arena size
MIN_ARENA_SIZE = int(sys.argv[3])
MAX_ARENA_SIZE = int(sys.argv[4])

# Operation count
MIN_OP_COUNT = int(sys.argv[5])
MAX_OP_COUNT = int(sys.argv[6])

# Maximum percentage of the arena that can be commited in a single allocation
# request
MAX_ALLOCATION = 10

# Percentage of operations that should be SHOW operations
SHOW_PERC = 10


commandsFile = open(sys.argv[1], "w")
outputFile = open(sys.argv[2], "w")

def sendCommand(allocOut, cmd):
        """Sends a command line both to the allocator and to the log file."""
        
        allocOut.write(cmd)
        commandsFile.write(cmd)
        
def readResponseLine(allocIn):
        """Read one line of response from the allocator and echoes it to the log file."""
        
        line = allocIn.readline()
        outputFile.write(line)
        
        return line

def simulate(allocOut, allocIn):
        """Performs the random allocation simulation."""
        random.seed()
        
        arenaSize = random.randint(MIN_ARENA_SIZE, MAX_ARENA_SIZE)
        blockList = []
        opCount = random.randint(MIN_OP_COUNT, MAX_OP_COUNT)
        
        
        sendCommand(allocOut, "INITIALIZE %d\n" % arenaSize)
        
        while opCount > 0:
                if random.randint(0, 100) < SHOW_PERC:
                        # We have a SHOW or DUMP operation
                        op = random.choice(["SHOW FREE", "SHOW USAGE", "SHOW ALLOCATIONS", "DUMP"])
                        sendCommand(allocOut, "%s\n" % op)
                        if op == "SHOW FREE":
                                readResponseLine(allocIn)
                        elif op == "SHOW USAGE":
                                readResponseLine(allocIn)
                                readResponseLine(allocIn)
                                readResponseLine(allocIn)
                        elif op == "SHOW ALLOCATIONS":
                                totalSize = 0
                                while totalSize < arenaSize:
                                        totalSize += int(readResponseLine(allocIn).split()[1])
                        elif op == "DUMP":
                                lineCount = arenaSize / 16 + ((arenaSize % 16) > 0) + 1
                                while lineCount > 0:
                                        readResponseLine(allocIn)
                                        lineCount-=1
                                        
                else:
                        # We have an allocation or release
                        op = random.choice(["ALLOC", "ALLOC", "FREE"])
                        if op == "ALLOC":
                                size = random.randint(1, MAX_ALLOCATION * arenaSize / 100)
                                sendCommand(allocOut, "ALLOC %d\n" % size)
                                block = int(readResponseLine(allocIn).strip())
                                if block > 0:
                                        sendCommand(allocOut, "FILL %d %d %d\n" %
                                                (block, size, random.randint(0, 255)))
                                        blockList.append(block)
                        elif op == "FREE":
                                if len(blockList) > 0:
                                        block = random.choice(blockList)
                                        blockList.remove(block)
                                        sendCommand(allocOut, "FREE %d\n" % block)
                opCount-=1
        
        sendCommand(allocOut, "FINALIZE\n")
        
        allocOut.close()
        allocIn.close()



# Create two pair of file descriptors for communicating with the allocator
(stdinReader, stdinWriter) = os.pipe()
(stdoutReader, stdoutWriter) = os.pipe()

# Fork ourselves
child = os.fork()

if child > 0:
        # We are in the parent
        
        # Close the other end of the pipes to avoid deadlocks
        os.close(stdinReader)
        os.close(stdoutWriter)
        
        simulate(os.fdopen(stdinWriter, 'w', 1), os.fdopen(stdoutReader, 'r', 1))
        
        os.wait()
else:
        # We are in the child - prepare to execute the allocator
        os.close(stdinWriter)
        os.close(stdoutReader)
        
        os.dup2(stdinReader, 0)
        os.dup2(stdoutWriter, 1)
        
        # Leave control here to the allocator
        os.execl(ALLOCATOR, ALLOCATOR)


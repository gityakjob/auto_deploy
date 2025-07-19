#!/bin/sh

# Print greeting message
echo "Hola desde Alpine!"
cat /app/build_message.txt

# Inform the user how to stop the container
echo "The container will keep running. Press Ctrl+C in your terminal to exit if you are in interactive mode, or use 'docker stop' if running detached."

# Infinite loop to keep the container alive
while true; do
  echo "The container is still running: $(date)"
  sleep 3
done
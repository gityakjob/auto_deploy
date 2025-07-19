# Use Alpine Linux as the base image
FROM alpine:latest

# Define a build-time argument (BUILD_ARG_MESSAGE)
ARG BUILD_ARG_MESSAGE="Default build message"

# Create a working directory
WORKDIR /app

# Copy a simple file to the container
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Create a dynamic file using the build argument
RUN echo "${BUILD_ARG_MESSAGE}" > /app/build_message.txt

# The container will run this script on startup
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

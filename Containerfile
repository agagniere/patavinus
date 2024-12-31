FROM alpine
WORKDIR /execute
ENV PATH="/execute"
COPY patavinus .
ENTRYPOINT ["patavinus"]

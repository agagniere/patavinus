FROM alpine
WORKDIR /execute
ENV PATH="/execute"
COPY inventaire .
ENTRYPOINT ["inventaire"]

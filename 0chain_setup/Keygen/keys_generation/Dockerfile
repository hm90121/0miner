FROM golang:latest

COPY ./entrypoint.sh /root/entrypoint.sh
COPY ./keys_file /0chain/go/0chain.net/core/
WORKDIR /0chain/go/0chain.net/core/
RUN chmod u+x /0chain/go/0chain.net/core/keys_file
CMD /root/entrypoint.sh

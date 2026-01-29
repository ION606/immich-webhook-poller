FROM alpine:latest

RUN apk add --no-cache jq bash curl

COPY poll.sh /poll.sh

RUN chmod +x poll.sh

CMD ["bash", "/poll.sh"]

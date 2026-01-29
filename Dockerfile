FROM alpine:latest

RUN apk add --no-cache jq bash

COPY poll.sh /poll.sh

RUN chmod +x poll.sh

CMD ["bash", "/poll.sh"]

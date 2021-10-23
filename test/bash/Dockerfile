FROM alpine:3.14

RUN apk add --no-cache bash curl git vim tmux

RUN addgroup -S user && adduser -s bash -S user -G user
USER user

WORKDIR "/app"
CMD [ "/bin/bash", "./test/test_main_guest.sh" ]

FROM alpine:3.14

RUN apk add --no-cache zsh curl git vim tmux

RUN addgroup -S user && adduser -s zsh -S user -G user
USER user

# Prevent an interactive zsh startup menu
RUN touch /home/user/.zshrc

WORKDIR "/app"
CMD [ "/bin/zsh", "./test/test_main_guest.sh" ]

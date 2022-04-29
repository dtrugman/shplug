FROM alpine:3.14

ARG shell
ENV SHELL="$shell"

ARG user=user

RUN apk add --no-cache "$SHELL" curl git vim tmux

RUN addgroup -S $user && adduser -s "$SHELL" -S $user -G $user
USER $user

# Prevent interactive menu on first zsh execution
RUN touch "${HOME}/.${SHELL}rc"

WORKDIR "/app"

# Copy repo and install shplug
COPY --chown="$user:$user" "." "./"
RUN "/bin/$SHELL" "./test/prepare_guest.sh"

# By default, assume running in manual testing mode
CMD "/bin/$SHELL"

# Project conventions

## Environment

This project runs on the host Mac, not inside the ramekin container.
Write and edit code here, but don't expect `bundle exec rake` or
other runtime commands to work — the user tests locally.

## Ruby

- No `frozen_string_literal` comments. Omit them from all Ruby files.

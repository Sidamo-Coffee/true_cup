# This configuration file will be evaluated by Puma. The top-level methods that
# are invoked here are part of Puma's configuration DSL. For more information
# about methods provided by the DSL, see https://puma.io/puma/Puma/DSL.html.

# Puma starts a configurable number of processes (workers) and each process
# serves each request in a thread from an internal thread pool.
#
# The ideal number of threads per worker depends both on how much time the
# application spends waiting for IO operations and on how much you wish to
# to prioritize throughput over latency.
#
# As a rule of thumb, increasing the number of threads will increase how much
# traffic a given process can handle (throughput), but due to CRuby's
# Global VM Lock (GVL) it has diminishing returns and will degrade the
# response time (latency) of the application.
#
# The default is set to 3 threads as it's deemed a decent compromise between
# throughput and latency for the average Rails application.
#
# Any libraries that use a connection pool or another resource pool should
# be configured to provide at least as many connections as the number of
# threads. This includes Active Record's `pool` parameter in `database.yml`.
threads_count = ENV.fetch("RAILS_MAX_THREADS", 3)
threads threads_count, threads_count

# Specifies the `port` that Puma will listen on to receive requests; default is 3000.
#
# ホスト `0.0.0.0` は明示する。Puma 8 は非ループバックの IPv6 インターフェースがある環境では
# 既定のバインド先が `::` になり、無ければ `0.0.0.0` に戻る（実行環境で変わる）。
# Render は「web サービスは 0.0.0.0 にバインドすること」を要件としているため、環境任せにしない。
#
# ここが効くのは `bundle exec puma` で直接起動した場合と、`bin/rails server` に
# `-b`/`-p` も `PORT`/`HOST`/`BINDING` も与えられていない場合。それらがあると
# Rails 側のホスト（本番は 0.0.0.0）で bind が上書きされ、この指定は使われない。
# Render は PORT を必ず設定するため、起動が `bin/rails server` なら実質 no-op になる。
# 起動方法によらず 0.0.0.0 にするための保険として置いている。
port ENV.fetch("PORT", 3000), "0.0.0.0"

# Allow puma to be restarted by `bin/rails restart` command.
plugin :tmp_restart

# Specify the PID file. Defaults to tmp/pids/server.pid in development.
# In other environments, only set the PID file if requested.
pidfile ENV["PIDFILE"] if ENV["PIDFILE"]

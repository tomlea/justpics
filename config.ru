$:.unshift File.expand_path("../lib", __FILE__)
require "justpics"
use Justpics::AlwaysFresh
run Justpics

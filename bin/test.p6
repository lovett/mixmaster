#!/usr/bin/env perl6

my @commands;
@commands.push: 'yes';

say @commands;

# sub MAIN() {
#     my $command = "echo hello again";

#     my $log = "tmp.log".IO.open(:w);

#     indir("BUILDS", {
#                  react {
#                      with Proc::Async.new: «$command» {
#                          whenever .stdout.lines {
#                              $log.say('OUT ', $_);
#                          }

#                          whenever .stderr {
#                              $log.say('ERR ', $_);
#                          }

#                          whenever .ready { say "ready"}

#                          whenever .start {
#                     spurt "test.log", "cwd test";
#                     say "Proc finished, exited with ", .exitcode, ', signal ', .signal;
#                 }
#             }
#         }
#     });

#     say "React block is finished";

#     CATCH {
#         default {
#             $log.say('DIE ', "{.message} ({$command})");
#         }
#     }


# }

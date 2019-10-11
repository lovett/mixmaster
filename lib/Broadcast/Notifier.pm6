unit module Broadcast::Notifier;

sub send() is export {
    say 'sending notifier in response to job start';
}

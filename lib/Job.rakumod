unit module Job;

use Config;
use Filesystem;
use JSON::Fast;

enum JobType <freestyle git task>;

sub load-job(IO::Path $path --> Hash) is export {
    my %job = from-json($path.slurp // "\{}");
    my $root = nearest-root($path);

    %job<mixmaster> = %{
        root => $root,
        config => load-config($root),
        jobfile => $path,
        jobtype => job-type(%job),
        workspace => Nil,
        checkout => Nil,
        archive => Nil,
        branch => Nil,
        project => Nil,
        recipe => [],
    }

    return %job;
}

sub job-type(%job --> JobType) {
    return freestyle if %job<scm> ~~ "freestyle";
    return task if %job<task>:exists;
    return git;
}

sub build-command(%job, Str $project, Str $branch --> Str) {
    my $matcher = $branch;
    if %job<mixmaster><jobtype> ~~ task {
        $matcher ~= "/{%job<task>}";
    }

    my Pair @matches = %job<mixmaster><config>{$project}.pairs.grep: {
        .key.starts-with($matcher);
    }

    given @matches.elems {
        when 1 {
            return @matches.first.value;
        }

        when 0 {
            return "# Build command not found for {$branch}";
        }

        default {
            my @keys = (.key for @matches);
            return "# Configuration for {$branch} is ambiguous. Could be {@keys.join(' or ')}.";
        }
    }
}

sub job-recipe(%job --> Hash) is export {
    if (%job<mixmaster><config><_><sshKey>) {
        %job<mixmaster><recipe>.push: "ssh-add -q {%job<mixmaster><config><_><sshKey>}"
    }

    given %job<mixmaster><jobtype> {
        when freestyle {
            return freestyle-recipe(%job);
        }

        when git {
            return git-recipe(%job);
        }

        when task {
            return task-recipe(%job);
        }
    }
}

sub freestyle-recipe(%job) {
    my Str @recipe;
    my $project = %job<project>;
    @recipe.push: "echo freestyle placeholder";
    return @recipe;
}

sub task-recipe(%job) {
    my Str @recipe;
    my $project = %job<project>;
    @recipe.push: "echo task placeholder";
    return @recipe;
}

sub git-recipe(%job) {
    my Str $project = %job<repository><full_name>;
    my Str $project-dir = filesystem-friendly($project);
    my Str $branch = %job<ref>.subst("refs/heads/", "");
    my Str $branch-dir = filesystem-friendly($branch);
    my IO::Path $workspace = %job<mixmaster><root>.add($project-dir).mkdir;

    my $checkout = $workspace.add($branch-dir).mkdir;
    my $archive = $workspace.add("ARCHIVE").mkdir;

    indir $checkout, {
        if (".git".IO.d) {
            %job<mixmaster><recipe>.push: "git reset --quiet --hard";
            %job<mixmaster><recipe>.push: "git checkout --quiet {$branch}";
            %job<mixmaster><recipe>.push: "git pull --ff-only";
        } else {
            %job<mixmaster><recipe>.push: "git clone --quiet --branch {$branch} {%job<repository><clone_url>} .";
        }
    };

    if (%job<after>) {
        %job<mixmaster><recipe>.push: "git checkout --quiet {%job<after>}";
    }

    %job<mixmaster><recipe>.push: build-command(%job, $project, $branch);

    if (%job<config><mode> ~~ "dryrun") {
        %job<mixmaster><recipe> = ("echo $_" for %job<mixmaster><recipe>);
    }

    %job<mixmaster><workspace> = $workspace;
    %job<mixmaster><checkout> = $checkout;
    %job<mixmaster><archive> = $archive;
    %job<mixmaster><branch> = $branch;
    %job<mixmaster><project> = $project;

    return %job;
}

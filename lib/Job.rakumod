unit module Job;

use Config;
use Filesystem;
use JSON::Fast;

enum JobType <freestyle git task>;

sub load-job(IO::Path $path --> Hash) is export {
    my %job = from-json($path.slurp // "\{}");

    %job<context> = Hash.new;
    %job<context><buildroot> = nearest-root($path);
    %job<context><config> = load-config(%job<context><buildroot>);
    %job<context><jobfile> = $path;
    %job<context><jobtype> = job-type(%job);

    %job<context><project> = job-project(%job);

    %job<context><project-dir> = filesystem-friendly(%job<context><project>);

    %job<context><workspace> = %job<context><buildroot>.add(%job<context><project-dir>).mkdir;

    %job<context><archive> = %job<context><workspace>.add("ARCHIVE").mkdir;

    %job<context><branch> = job-branch(%job);

    %job<context><branch-dir> = filesystem-friendly(%job<context><branch>);

    %job<context><checkout> = %job<context><workspace>.add(%job<context><branch-dir>).mkdir;

    %job<context><build-command> = build-command(%job);

    %job<context><recipe> = job-recipe(%job);

    %job<context><log-path> = job-log-path(%job);

    %job<context><log> = open %job<context><log-path>, :a;

    return %job;
}

sub job-type(%job --> JobType) {
    return freestyle if %job<scm> ~~ "freestyle";
    return task if %job<task>:exists;
    return git;
}

sub job-log-path(%job --> IO::Path) {
    my $log-filename = %job<context><jobfile>.basename.IO.extension: 'log';
    return %job<context><archive>.add($log-filename);
}

sub job-project(%job --> Str) {
    given %job<context><jobtype> {
        when git {
            return %job<repository><full_name>;
        }

        default {
            return %job<project>;
        }
    }
}

sub job-branch(%job --> Str) {
    given %job<context><jobtype> {
        when git {
            return %job<ref>.subst("refs/heads/", "");
        }

        default {
            return "";
        }
    }
}

sub build-command(%job --> Str) {
    my $project = %job<context><project>;
    my $branch = %job<context><branch>;

    my $matcher = $branch;
    if %job<context><jobtype> ~~ task {
        $matcher ~= "/{%job<task>}";
    }

    my Pair @matches = %job<context><config>{$project}.pairs.grep: {
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

sub job-recipe(%job --> Array[Str]) is export {
    my Str @recipe = [];

    my $key = %job<context><config><_><sshKey>;

    if ($key) {
        @recipe.push: "ssh-add -q {$key}"
    }

    given %job<context><jobtype> {
        when freestyle {
            @recipe.append: freestyle-recipe(%job);
        }

        when git {
            @recipe.append: git-recipe(%job);
        }

        when task {
            @recipe.append: task-recipe(%job);
        }
    }

    @recipe.push: %job<context><build-command>;

    if (%job<context><config><mode> ~~ "dryrun") {
        @recipe = ("echo $_" for @recipe);
    }

    return @recipe;
}

sub freestyle-recipe(%job) {
    return ["echo freestyle placeholder"];
}

sub task-recipe(%job) {
    return ["echo task placeholder"];
}

sub git-recipe(%job) {
    my Str @recipe;
    my Str $branch = %job<context><branch>;
    my IO::Path $checkout = %job<context><checkout>;
    my Str $clone-url = %job<repository><clone_url>;
    my Str $revision = %job<after>;

    if ($checkout.add(".git").d) {
        @recipe.push: "git reset --quiet --hard";
        @recipe.push: "git checkout --quiet {$branch}";
        @recipe.push: "git pull --ff-only";
    } else {
        @recipe.push: "git clone --quiet --branch {$branch} {$clone-url} .";
    }

    if ($revision) {
        @recipe.push: "git checkout --quiet {$revision}";
    }

    return @recipe;
}

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
    }

    return %job;
}

sub job-type(%job --> JobType) {
    return freestyle if %job<scm> ~~ "freestyle";
    return task if %job<task>:exists;
    return git;
}

sub build-command(%job, Str $project, Str $target --> Str) {
    my $matcher = $target;

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
            return "# Build command not found for {$target}";
        }

        default {
            my @keys = (.key for @matches);
            return "# Configuration for {$target} is ambiguous. Could be {@keys.join(' or ')}.";
        }
    }
}

sub job-recipe(%job --> List) is export {
    my Str @recipe;

    if (%job<mixmaster><config><_><sshKey>) {
        @recipe.push: "ssh-add -q {%job<mixmaster><config><_><sshKey>}"
    }

    given %job<mixmaster><jobtype> {
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
    return @recipe;
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
    @recipe.push: "echo ta placeholder";
    return @recipe;
}

sub git-recipe(%job) {
    my Str @recipe;
    my $project = %job<repository><full_name>;
    my $projectDir = filesystem-friendly($project);
    my $target = %job<ref>.subst("refs/heads/", "");
    my $path = %job<mixmaster><root>.add($projectDir).add($target);

    unless $path.d {
        @recipe.push: "mkdir -p {$path}";
    }

    if ($path.add('.git').d) {
        @recipe.push: "git reset --quiet --hard";
        @recipe.push: "git checkout --quiet {$target}";
        @recipe.push: "git pull --ff-only";
    } else {
        @recipe.push: "git clone --quiet --branch {$target} {%job<repository><clone_url>} .";
    }

    if (%job<after>) {
        @recipe.push: "git checkout --quiet {%job<after>}";
    }

    @recipe.push: build-command(%job, $project, $target);

    if (%job<config><mode> ~~ "dryrun") {
        return ("echo $_" for @recipe);
    }

    return @recipe;
}

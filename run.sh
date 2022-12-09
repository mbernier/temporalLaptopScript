echo "\n"

function test_and_create_file() {
    test_file "$1"
    if [[ "$fileExists" -eq 0 ]]; then
        if [[ 0 != "$2" ]]; then
            echo "Creating File:'$1'"
        fi
        touch $1
    fi 
}

function test_file() {
    fileExists=0
    if [ -f "$1" ]; then
        if [[ 0 != "$2" ]]; then
            echo "File: '$1' exists"
        fi
        fileExists=1
    else
        if [[ 0 != "$2" ]]; then
            echo "File: '$1' does not exist"
        fi
    fi
}

function test_and_create_dir() {
    #$1 is the directory
    test_dir "$1" 0
    if [[ 0 -eq dirExists ]]; then
        echo "$1 doesn't exist yet"
        create_dir_set_perms "$1" "+rwx"
    else
        echo "We'll go ahead and use '$1' for next steps"
        create_dir_success=1
        set_dir_perms "$1" "+rwx"
    fi
}

function create_dir_set_perms(){
    #$1 is the directory 
    #$2 is the permissions +rwx is good for execution
    echo "Attempting to create '$1'"
    create_dir_success=0
    mkdir_response=$(mkdir "$1" 2>&1)
    if [[ -z "$mkdir_response" ]]; then
        echo "Successfully created '$1'"
        create_dir_success=1
        set_dir_perms $1 $2
    else
        echo "Failed to create '$1'"
    fi
}

function set_dir_perms(){
    #$1 is the directory 
    #$2 is the permissions +rwx is good for execution
    echo "Setting permissions for '$1' to '$2'"
    chmod_response=$(chmod "$2" "$1" 2>&1)
    if [[ -z "$chmod_response" ]]; then
        echo "Successfully set permissions for '$1' to '$2'"
        create_dir_success=2
    else 
        echo "Failed to set permissions for '$1' to '$2'"
    fi
}


function test_dir() {
    dirExists=0
    if [ -d "$1" ]; then
        if [[ 0 != "$2" ]]; then
            echo "Directory: '$1' exists"
        fi
        dirExists=1
    else 
        if [[ 0 != "$2" ]]; then
            echo "Directory: '$1' not found"
        fi
    fi
}

function test_dir_run_code() {
    #$1 is the directory 
    #$2 is whether we echo about the directory
    #$3 is the code to run
    test_dir "$1" "$2" 
    if [[ 1 -eq dirExists ]]; then
        eval $3
    fi
}

function read_loop_y_n(){
    #$1 is message to send
    echo "$1"
    read read_loop_value
    while [[ "$read_loop_value" != "y" ]] && [[ "$read_loop_value" != "n" ]] ; do
        echo "Incorrect input, expected 'y' or 'n', got $read_loop_value"
        echo "$1"
        read read_loop_value
    done
}

function read_loop_input_confirm(){
    # $1 is the value for the first question
    # $2 is the type of thing we're setting ... "username"
    # $3 is the use case
    changed_input=0
    echo "\nIs '$1' the correct $2 for $3? y/n"
    read yes_no_confirm
    while [[ "$yes_no_confirm" == "n" ]] ; do
        echo "What is the correct $2 for $3?"
        read yes_no_input
        changed_input=1
        echo "You set $2 to '$yes_no_input', is this correct? y/n"
        read yes_no_confirm
    done
}

function read_loop_run_action(){
    # $1 is the question to display
    # $2 is the "we are running message"
    # $3 is the action we're running
    read_loop_y_n "$1"
    if [[ "$read_loop_value" == "y" ]]; then
        echo "$2"
        eval $3
    fi
}

function check_a_setting(){
    # $1 is the thing to get the setting for
    # $2 is the type of thing we're setting ... "username"
    # $3 is the use case     
    # $4 is the command to run, replacing "{{value}}" with the yes_no_input
        # e.g. git config --global user.email "{{value}}"
    the_setting_value=$4
    read_loop_input_confirm "$the_setting_value" "$1" "$2"
    if [[ "$changed_input" == 1 ]]; then
        subs=${3/~~value~~/$yes_no_input}
        echo "Setting $1 to $yes_no_input for $2"
        eval $subs
    else
        # make sure we set the same variable we would have gotten from read
        yes_no_input="$the_setting_value"
        echo "Awesome, we'll use $the_setting_value for $1"
    fi
}

function check_a_setting_dir(){
    # $1 is the thing to get the setting for
    # $2 is the type of thing we're setting ... "username"
    # $3 is the use case     
    # $4 is the command to run, replacing "{{value}}" with the yes_no_input
        # e.g. git config --global user.email "{{value}}"
    the_setting_value=$3

    # reset this value for each time we run this function, just in case
    create_dir_success=0
    while [[ $create_dir_success -lt 2 ]]; do
        read_loop_input_confirm "$the_setting_value" "$1" "$2"

        if [[ "$changed_input" == 1 ]]; then
            echo "Setting $1 to $yes_no_input for $2"
        else
            # make sure we set the same variable we would have gotten from read
            yes_no_input="$the_setting_value"
            echo "Awesome, we'll use $the_setting_value for $1"
        fi

        subs="test_and_create_dir $yes_no_input"
        eval $subs

        # we created the dir, but couldn't set perms
        if [[ $create_dir_success -eq 1 ]]; then
            echo "\n\nWarning: We could not set the permissions on $yes_no_input, but we did create it\n\n"
        fi

        # failure to provide a good directory path
        if [[ $create_dir_success -eq 0 ]]; then
            echo "\n\nThat was an invalid directory path, please try again..."
        fi
    done
}

function check_github_login_status(){
    gh_ssh_output=$(ssh -T git@github.com 2>&1)
    gh_username=`echo "$gh_ssh_output" | sed 's/.*Hi \([0-9a-z]*\)!.*/\1/'`
    
    if [[ "$gh_ssh_output" == *"Permission denied"* ]]; then
        echo "You are not currently logged into Github over ssh"

        read_loop_y_n "Would you like to get setup for Github over ssh? y/n"

        approve_gh_setup=read_loop_value

        if [[ "y" == "$approve_gh_setup" ]]; then
            #run setup github method
            setup_github
        else
            read_loop_y_n "Github has you logged in as ${gh_username}, is this the correct username? y/n"
            approve_gh_setup=read_loop_value

            # wrong username, let's go through setup
            if [[ "n" == "$approve_gh_setup" ]]; then
                #run setup github method
                setup_github
            fi
        fi
    fi
}

function check_github_settings(){
    check_a_setting "user name" "github" "git config --global user.name \"~~value~~\"" `git config user.name`

    check_a_setting "email" "github" "git config --global user.email \"~~value~~\"" `git config user.email`

    check_a_setting "editor" "github" "git config --global core.editor \"~~value~~\"" `git config core.editor`

    check_a_setting "default branch name" "github" "git config --global init.defaultBranch \"~~value~~\"" `git config init.defaultBranch`
    echo "\n"
}

function setup_github(){
    #https://medium.com/macoclock/github-setup-for-mac-os-x-2b0ba5809e6

    idRsaPath="$HOME/.ssh"
    test_dir "$idRsaPath" 0

    idRsaFilePath="$idRsaPath/id_rsa"
    test_file "$idRsaFilePath" 0

    use_current_rsa="n"
    if [[ "$fileExists" == 1 ]]; then
        echo "You already have an rsa key setup"
        echo "Would you like to use that key for github? y/n"
        read use_current_rsa
    fi

    if [[ "$use_current_rsa" == "n" ]] || [[ "$fileExists" == 0 ]]; then
        echo "Provide a postfix for your new rsa file, suggest: 'github'"
        read rsa_postfix
        test_file "$HOME/.ssh/id_rsa_$rsa_postfix"
        while [[ "$fileExists" != 0 ]]; do
            echo "Provide a postfix for your new rsa file, suggest: 'github'"
            read rsa_postfix
            test_file "$idRsaFilePath_$rsa_postfix"
        done
        newRsaFile="${idRsaFilePath}_${rsa_postfix}"
        echo "Creating new RSA Key '$newRsaFile' for Github"
        ssh-keygen -t rsa -C "$gh_email" -f "$newRsaFile"
    else
        pbcopy < "$newRsaFile"
        echo "Your rsa key is copied to your clipboard"
        read_loop_run_action "Is it ok if I open a browser to https://github.com/settings/keys, so you can enter your new rsa key?" "Opening Browser" "open https://github.com/settings/keys"        
    fi
}

function check_exists_by_calling_version() {
    #$1 is the thing to check version on
    versionOfThing=`eval ${1} ${2}`
    versionNumberOfThing=`$1 $2 | sed 's/[^0-9\.]*//g' | head -1`
    if [[ "$versionOfthing" == *"${1} version"* ]]; then
        check_exists_value=0
    else 
        check_exists_value=1
    fi
}

function if_not_exists_install() {
    # $1 is the thing to install
    # $2 is the install command
    # $3 is the version command -- not required

    if [ -z $3 ]; then
        versionParam="--version"
    else
        versionParam=$3
    fi
    check_exists_by_calling_version $1 $versionParam
    if [[ check_exists_value == 0 ]]; then
        echo "$1 is not installed, installing now..."
        eval $2
    else
        echo "Found version $versionNumberOfThing of $1 is installed, skipping install"
    fi
}

function if_not_exists_brew_install(){
    # $1 is the thing to install
    # $2 is if it has a version command other than --version
    # 
    if [ -z "$2" ]; then
        if_not_exists_install "$1" "brew install $1" 
    else
        if_not_exists_install "$1" "brew install $1" "$2"
    fi
 }

function clone_a_repo(){
    # $1 is the repo to clone
    # $2 is the path to clone it to
    repo="temporalio/${1}"
    path="${2}${1}"
    echo "\nChecking if $repo has already been cloned to $path"
    test_dir "$path" 1
    skip_clone=0
    if [[ dirExists -eq 1 ]]; then
        gitRemoteResponse=$(cd $path; git remote -v)
    
        if [[ "$gitRemoteResponse" == *"$repo"* ]];then
            echo "$repo already exists at $path, skipping"
            skip_clone=1
        fi
    fi

    if [[ $skip_clone -eq 0 ]]; then
        echo "Cloning $repo to $path"
        gh repo clone "$repo" "$path"
    fi
}


#install xcode
if_not_exists_install "xcode-select" "xcode-select --install"

# install homebrew
if_not_exists_install "brew" "/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""

if brew doctor | grep -q 'Your system is ready to brew'; then
    echo "brew is installed and ready to go"
else
    echo "brew is unhappy, attempting `brew cleanup`"
    brew cleanup

    if brew doctor | grep -q 'Your system is ready to brew'; then
        echo "brew is installed and ready to go"
    else
        echo "`brew cleanup` didn't fix the problem, this is what `brew doctor` says"
        brew doctor
        exit
    fi
fi

    
    echo "Setting your homebrew permissions to 'execute' permission"
    chmod +rwx /opt/homebrew/bin/
    
    echo "Setting your homebrew .keepme file permissions to 'execute' permissions"
    chmod +rwx /opt/homebrew/bin/.keepme

    # check if we should install git
    if_not_exists_brew_install "git"

    if git --version | grep -q 'git version'; then

        # check if gh is installed, if not then install it        
        if_not_exists_brew_install "gh"

        # run the method for checking whether we're logged in
        check_github_login_status
        
        # lets make sure you have the github settings correct
        check_github_settings

        # check if node is installed, if not then install it
        if_not_exists_brew_install "node"

        # check if python is installed, if not then install it
        if_not_exists_brew_install "python3"

        if_not_exists_brew_install "go" "version"

        check_a_setting_dir "directory" "cloning your github repos" `echo "$HOME/projects/"`
        # double check that trailing slash
        if [[ "${yes_no_input: -1}" != "/" ]]; then
            clone_path_root="${yes_no_input}/"
        else
            clone_path_root="${yes_no_input}"
        fi

        temporalGhPath="${clone_path_root}temporal/"

        check_a_setting_dir "directory" "cloning temporal github repos" `echo "$temporalGhPath"`
        # double check that trailing slash
        if [[ "${yes_no_input: -1}" != "/" ]]; then
            temporalGhPath="${clone_path_root}/"
        else
            temporalGhPath="${yes_no_input}"
        fi

        echo "Cloning some of the Temporal github repos for you..."
        
        clone_a_repo "temporalite" "$temporalGhPath"
        clone_a_repo "documentation" "$temporalGhPath"
        clone_a_repo "sdk-python" "$temporalGhPath"
        clone_a_repo "sdk-typescript" "$temporalGhPath"
        clone_a_repo "sdk-go" "$temporalGhPath"
        clone_a_repo "sdk-java" "$temporalGhPath"
        clone_a_repo "sdk-php" "$temporalGhPath"

        echo "\n\n Your basic setup is complete\n"

    else
        echo "git failed to install, try running `brew install git` or scrolling up for error messages and then run this script again"
    fi

# else
#     echo "brew failed to install, scroll up for errors or trying running this script again"
# fi


echo "\n"
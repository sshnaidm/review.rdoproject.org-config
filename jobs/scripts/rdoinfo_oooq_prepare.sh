# This builder, when run from a child job of validate-buildsys-tags
# configures the temporary repositories created by it
# This allows to install the packages in that repository and test
# them.
set +e -x
# This job requires variables $RELEASE and $PHASE to be defined.

PHASE='{buildsys_phase}'
RELEASE='{openstack_release}'

REQUIRED=0
MASTER_RELEASE=pike
CREPOS_FILE=changed_repos.txt

if [ -z "$RELEASE" -o -z "$PHASE" ]; then
    echo "ERROR in job definition"
    exit 1
fi

if [ $RELEASE = "master" ]; then
    O_RELEASE=$MASTER_RELEASE
else
    O_RELEASE="$RELEASE"
fi

# Re-construct the expected repository URL
ZUUL_REF=$(echo $ZUUL_REF |cut -f4 -d /)
job="validate-buildsys-tags"
LOG_PATH="$BASE_LOG_PATH/$ZUUL_PIPELINE/$job/$ZUUL_REF"
logs="https://logs.rdoproject.org/$LOG_PATH/"
# If we couldn't find a working repository, give up
curl -o $CREPOS_FILE -sf "$logs/repos/changed_repos.txt" || exit 1

for tag in $O_RELEASE common
do
    if grep -q -E "$tag-$PHASE" $CREPOS_FILE; then
        REQUIRED=1
    fi
done

if [ $REQUIRED -eq 0 ];then
    echo "INFO: this test is not required"| tee not_required
    exit 0
fi


COMMON_TESTING_TAG="cloud7-openstack-common-testing"
COMMON_RELEASE_TAG="cloud7-openstack-common-release"
COMMON_TESTING=$(grep -c $COMMON_TESTING_TAG $CREPOS_FILE)
COMMON_RELEASE=$(grep -c $COMMON_RELEASE_TAG $CREPOS_FILE)

function create_config(){{
    echo "release: $RELEASE"
    echo "overcloud_image_url: file:///var/lib/oooq-images/$RELEASE/overcloud-full.tar"
    echo "ipa_image_url: file:///var/lib/oooq-images/$RELEASE/ironic-python-agent.tar"
    echo "repos:"
    if [ $STABLE_REPOSITORIES != false ]; then
        echo "  - type: package"
        echo "    pkg_name: centos-release-openstack-$O_RELEASE"
        echo "    custom_cmd: 'sudo yum install -y --enablerepo=extras'"
    fi
    INDEX=0
    for repo in $REPOS_URL
    do
        echo "  - type: file"
        echo "    filename: delorean-$INDEX.repo"
        echo "    down_url: $repo"
        ((INDEX++))
    done
    echo "  - type: package"
    echo "    pkg_name: centos-release-ceph-jewel"
    echo "    custom_cmd: 'sudo yum install -y --enablerepo=extras'"
    echo "repo_cmd_after: |"
    echo "  sudo yum-config-manager --save --setopt centos-ceph-jewel.gpgcheck=0"
    if [ $STABLE_REPOSITORIES != false ]; then
        echo "  sudo yum-config-manager --save --setopt centos-qemu-ev.gpgcheck=0"
        echo "  sudo yum-config-manager --save --setopt centos-openstack-$O_RELEASE.gpgcheck=0"
        echo "  sudo yum-config-manager --disable rdo-trunk-$O_RELEASE-tested"
        if [ $TESTING_REPOSITORY = true ]; then
            echo "  sudo yum-config-manager --disable centos-openstack-$O_RELEASE"
            echo "  sudo yum-config-manager --enable centos-openstack-$O_RELEASE-test"
        fi
    fi
    echo "  sudo yum clean all;"
    echo "  sudo yum repolist;"
    echo "  sudo yum update -y"
    if [ $STABLE_REPOSITORIES != false ]; then
        echo "overcloud_repo_paths:"
        echo "  - \"\$(ls /etc/yum.repos.d/CentOS-OpenStack-$O_RELEASE*)\""
        echo "  - \"\$(ls /etc/yum.repos.d/CentOS-QEMU*)\""
        echo "  - \"\$(ls /etc/yum.repos.d/CentOS-Ceph-*)\""
        INDEX=0
        for repo in $REPOS_URL
        do
            echo "  - \"/etc/yum.repos.d/delorean-$INDEX.repo\""
            ((INDEX++))
        done
    fi
}}


case $PHASE in
testing)
    if [ $RELEASE = master ]; then
        REPOS_URL="http://trunk.rdoproject.org/centos7-$O_RELEASE/current-passed-ci/delorean.repo http://trunk.rdoproject.org/centos7-$O_RELEASE/delorean-deps.repo"
        STABLE_REPOSITORIES=false
        TESTING_REPOSITORY=false
    else
        REPOS_URL=""
        STABLE_REPOSITORIES=true
        TESTING_REPOSITORY=true
    fi
    if [ $(grep -c $O_RELEASE-$PHASE $CREPOS_FILE) -ne 0 ]; then
        REPO="cloud7-openstack-$O_RELEASE-$PHASE"
        REPOS_URL="$REPOS_URL $logs/repos/$REPO/temp-$REPO.repo"
    fi
    if [ $COMMON_TESTING -ne 0 ];then
        REPOS_URL="$REPOS_URL $logs/repos/$COMMON_TESTING_TAG/temp-$COMMON_TESTING_TAG.repo"
    fi
    create_config | tee -a tripleo.yml
;;
release)
    STABLE_REPOSITORIES=true
    TESTING_REPOSITORY=false
    if [ $(grep -c $O_RELEASE-$PHASE $CREPOS_FILE) -ne 0 ]; then
        REPO="cloud7-openstack-$O_RELEASE-$PHASE"
        REPOS_URL="$logs/repos/$REPO/temp-$REPO.repo"
    else
        REPOS_URL=""
    fi
    if [ $COMMON_RELEASE -ne 0 ];then
        REPOS_URL="$REPOS_URL $logs/repos/$COMMON_RELEASE_TAG/temp-$COMMON_RELEASE_TAG.repo"
    fi
    create_config | tee -a tripleo.yml
;;
esac
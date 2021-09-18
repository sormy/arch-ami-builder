# Arch Linux AMI Builder

This is AWS EC2 AMI image builder for Arch Linux.

This builder tries to keep image as clean as possible from not needed stuff and
installs just minimal set of applications needed to get bootable Arch Linux on
EC2 instances.

For example, this builder doesn't even install Python. Usually Python is pulled
by awslogs, aws-cli or cloud-init, but this builder uses tiny alternatives like
shell-based ec2-init and aws-curl to call AWS services and to use EC2 metadata
to configure ssh keys and invoke EC2 initialization commands.

The time to build AMI usually depends only on CPU, since kernel is built inside
instance.

Only arm64 instances are supported at this time. If you are looking for amd64
AMI images, then they are available
[here](https://www.uplinklabs.net/projects/arch-linux-on-ec2/).

Produced AMI can be used to spawn new instances. Produced AMIs support partially
functionality of `cloud-init` without pulling Python. See
[ec2-init](https://github.com/sormy/ec2-init) for more details.

## Usage

This repo has two scripts, one for automatic bootstrap `arch-ami-builder` and
one for manual bootstrap `arch-ami-sideload`.

Below you can read about different available methods.

### Automatic bootstrap using ssh

This is default mode and it provides a good visibility to what is happenning
since bootstrap process is executed over SSH.

Script requires aws-cli and aws credentials to run (create aws resources,
including spawning EC2 instance). Grant `AmazonEC2FullAccess` and
`IAMFullAccess` to the user that will invoke the script.

Script creates all necessary resources like security group, IAM role, EC
instance profile, S3 bucket for bootstrap scripts. Bootstrap scripts are
uploaded over SSH to the instance and are invoked over SSH to track the progress
in terminal. The process will require one reboot and script will automatically
reconnect SSH session after reboot.

Once the process will be completed, the EC2 instance will be terminated.

If something will go wrong, EC2 instance could get stuck and still running.
Usually, if something fails, you can see a root cause straight in the terminal.
If instance doesn't boot properly, then you could use EC2 serial console access
from AWS console to get know more details about what went wrong during boot.

Keep in mind, provisioning using SSH requires SSH key pair created in AWS
console and installed locally so your ssh client can connect to EC2 instance.

You can run script as below to use this mode:

```sh
PROVISION_MODE=ssh EC2_KEY_PAIR="My Keys" ./arch-ami-builder
```

There are more options available, please see below.

### Automatic bootstrap using ec2-init

This is the mode that can be used to run the bootstrap process in the cloud in
detached mode.

Script requires aws-cli and aws credentials to run (create aws resources,
including spawning EC2 instance). Grant `AmazonEC2FullAccess` and
`IAMFullAccess` to the user that will invoke the script.

Script creates all necessary resources like security group, IAM role, EC
instance profile, S3 bucket for bootstrap scripts. Bootstrap scripts with all
configuration are uploaded to S3 bucket and EC2 instance is spawned with user
data set to automatically invoke bootstrap process during cloud-init.

The process will continue on EC2 instance and you could track the progress if
you need using EC2 serial console access using AWS console for initial phase.

Final phase requires using ssh access and key pair to track the progress.

Once the process will be completed, the EC2 instance will be terminated.

If something will go wrong, EC2 instance could get stuck and still running.
Usually the process takes no more than 1 hour. If after 1 hour you will see that
EC2 instance is still running, then use EC2 serial console to find root cause,
submit an issue and terminate the instance to avoid extra charge.

You can run script as below to use this mode:

```sh
PROVISION_MODE=ec2-init ./arch-ami-builder
```

There are more options available, please see below.

### Manual bootstrap using ssh

This is minimalistic process that requires some upfront manual work, mostly to
create AWS resources including spawning EC2 instance. Once EC2 is spawned the
script will help to upload bootstrap scripts. The rest of the bootstrap process
will be in your hands. Usually, if everything is ok, it is just as simple as
running shell scripts over ssh twice (before reboot and after).

Once the process will be completed, the EC2 instance will be terminated.

1. Launch EC2 instance with following parameters:

    - latest Amazon Linux 2 AMI, arm64 architecture
    - any arm64 instance type, recommended is a1.2xlarge (faster) or t4g.micro
      (cheaper)
    - security group that allows to connect from public internet on 22 port
      (ssh)
    - 15 GB primary hard drive and 15 GB secondary hard drive (remove on
      shutdown)
    - use key pair you have access to (to login using ssh)
    - attach instance role with this [policy](lib/config/ec2-policy.json).

2. Sideload bootstrap script:

    ```sh
    ./arch-ami-sideload ec2-user@ec2-hostname
    ```

3. You will need to trigger initial phases:

    ```sh
    ssh -t ec2-user@ec2-hostname sudo /mnt/arch-bootstrap/bootstrap.sh
    ```

4. And, after reboot, finalize bootstrap by running remaining final phases:

    ```sh
    ssh -t alarm@ec2-hostname sudo /mnt/arch-bootstrap/bootstrap.sh
    ```

    You will likely need to edit `~/.ssh/known_hosts` and remove previous key
    association with the host.

5. Once process is completed the instance will be terminated and the image
   creation will be continued in background by AWS.

Configuration is performed once using environment variables during sideload.

## Configuration

There are two groups of environment variables available. The first group is
responsible for the provisioning process and the second group is responsible for
the bootstrap process itself.

Provisioning variables:

| Name               | Description                        | Default Value                | Class | Mode     |
| ------------------ | ---------------------------------- | ---------------------------- | ----- | -------- |
| PROVISION_MODE     | Provision mode: ssh, ec2-init      | ssh                          | main  | all      |
| AWS_REGION         | AWS region                         | us-east-1                    | main  | all      |
| EC2_ARCH           | EC2 architecture: amd64, arm64     | arm64                        | main  | all      |
| EC2_AMZN2_IMAGE_ID | EC2 Amazon Linux 2 AMI image ID    | auto                         | debug | all      |
| EC2_INSTANCE_TYPE  | EC2 provisioning instance type     | auto                         | tweak | all      |
| EC2_VOLUME_SIZE    | EC2 root volume size               | 15GB                         | tweak | all      |
| EC2_VOLUME_TYPE    | EC2 root volume type               | gp2                          | tweak | all      |
| EC2_KEEP_AUX_DISK  | Keep aux disk volume?              | false                        | debug | all      |
| EC2_KEY_PAIR       | AWS key pair name                  | no but required for ssh      | main  | all      |
| EC2_SECURITY_GROUP | EC2 security group name            | arch-ami-builder             | tweak | all      |
| EC2_ROLE           | IAM role to attach to EC2 instance | arch-ami-builder             | tweak | all      |
| EC2_CLEANUP        | Terminate instance if running      | true                         | debug | ssh      |
| SIDELOAD_S3_PATH   | Sideload s3 path                   | arch-ami-builder-{acc}-{reg} | tweak | ec2-init |
| SIDELOAD_EC2_PATH  | Sideload ec2 path                  | /mnt/arch-bootstrap          | debug | all      |
| SIDELOAD_EC2_CLEAN | Clean ec2 sideload path before?    | false                        | debug | ssh      |

Classes:

-   `main` - important parameters
-   `tweak` - optional parameters needs for specific use cases
-   `debug` - just for debugging if something goes wrong

See [params](lib/bootstrap/params.sh) for bootstrap variables.

## Troubleshooting

Time moves fast and AWS and Arch are too. The script that works Today could stop
working Tomorrow. There is no automatic build running periodically on CI so
please report any issues if you experience them.

Even if you are using `ec2-init` mode, it is good to have SSH access to the
instance for troubleshooting, so don't forget to pass `EC2_KEY_PAIR`.

EC2 serial console is also a good troubleshooting friend, especially for
`ec2-init` mode.

In any case:

1. Try to find root cause (terminal logs, ec2 serial logs etc).
2. Fix it if you can and submit PR ;-). PRs are very welcome!
3. If you can't fix then submit issue and maintainers will take a look.

## Contribution

There are a bunch of improvements could be done. Take a look on `TODO.md`.

PRs are very welcome!

## License

MIT License

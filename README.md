# Arch Linux AMI Builder

This is AWS EC2 AMI image builder for Arch Linux.

This builder tries to keep image as clean as possible from not needed stuff and
installs just minimal set of applications needed to get bootable Arch Linux
on EC2 instances.

For example, this builder doesn't even install Python. Usually Python is pulled
by awslogs, aws-cli or cloud-init, but this builder uses tiny alternatives
like shell-based ec2-init and aws-curl to call AWS services and to use EC2
metadata to configure ssh keys and invoke initialization commands.

The time to build AMI usually depends only on CPU, since kernel is built inside
instance.

At this time, the builder requires some manual actions to trigger the builder.

Only arm64 instances are supported at this time. If you are looking for amd64
AMI images, then they are available
[here](https://www.uplinklabs.net/projects/arch-linux-on-ec2/).

## Usage

1. Launch EC2 instance with following parameters:

    - latest Amazon Linux 2 AMI, arm64 architecture
    - any arm64 instance type, recommended is a1.2xlarge (faster) or t4g.micro (cheaper)
    - security group that allows to connect from public internet on 22 port (ssh)
    - 15 GB primary hard drive and 15 GB secondary hard drive (remove on shutdown)
    - use key pair you have access to (to login using ssh)
    - attach instance role with this [policy](lib/config/ec2-policy.json).

2. Sideload bootstrap script:

    ```sh
    ./arch-ami-sideload.sh ec2-user@ec2-hostname
    ```

3. You will need to trigger phases 1-3:

    ```sh
    ssh -t ec2-user@ec2-hostname sudo /mnt/arch-bootstrap/bootstrap.sh
    ```

4. And, after reboot, finalize bootstrap by running remaining phases 4-6:

    ```sh
    ssh -t alarm@ec2-hostname sudo /mnt/arch-bootstrap/bootstrap.sh
    ```

    You will likely need to edit `~/.ssh/known_hosts` and remove previous
    key association with the host.

5. Once process is completed the instance will be terminated and the image
   creation will be continued in background by AWS.

Produced AMI can be used to spawn new instances as with usual images. It supports
partially functionality of cloud-init without pulling python. See
[ec2-init](https://github.com/sormy/ec2-init) for more details.

## Configuration

Configuration is performed once using environment variables during sideload.

See [params](lib/bootstrap/params.sh) for bootstrap variables.

Sideload variables:

| Name           | Description                 | Default Value       |
| -------------- | --------------------------- | ------------------- |
| SIDELOAD_PATH  | Sideload path               | /mnt/arch-bootstrap |
| SIDELOAD_CLEAN | Clean sideload path before? | false               |

## License

MIT License

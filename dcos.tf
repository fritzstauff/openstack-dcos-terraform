resource "openstack_compute_keypair_v2" "keypair" {
  name       = "terraform-key"
  public_key = "${file(var.dcos_ssh_public_key_path)}"
}

resource "openstack_networking_floatingip_v2" "dcos_bootstrap_ip" {
  pool = "hvfloating-894"
}

resource "openstack_compute_instance_v2" "dcos_bootstrap" {
  name            = "${format("${var.dcos_cluster_name}-bootstrap-%02d", count.index)}"
  flavor_id       = "${var.openstack_flavor_id}"
  key_pair        = "terraform-key"
  security_groups = ["default"]

  block_device {
    uuid                  = "${var.openstack_image_id}"
    source_type           = "image"
    destination_type      = "volume"
    volume_size           = 20
    boot_index            = 0
    delete_on_termination = true
  }

  network {
    name = "${var.openstack_network_name}"
  }
}

resource "openstack_compute_floatingip_associate_v2" "dcos_bootstrap_ip" {
  floating_ip = "${openstack_networking_floatingip_v2.dcos_bootstrap_ip.address}"
  instance_id = "${openstack_compute_instance_v2.dcos_bootstrap.id}"

}

resource "openstack_networking_floatingip_v2" "dcos_master_ips" {
  count = "${var.dcos_master_count}"
  pool  = "hvfloating-894"
}

resource "openstack_compute_instance_v2" "dcos_master" {
  name            = "${format("${var.dcos_cluster_name}-master-%02d", count.index)}"
  count           = "${var.dcos_master_count}"
  flavor_id       = "${var.openstack_flavor_id}"
  key_pair        = "terraform-key"
  security_groups = ["default"]

  block_device {
    uuid                  = "${var.openstack_image_id}"
    source_type           = "image"
    destination_type      = "volume"
    volume_size           = 20
    boot_index            = 0
    delete_on_termination = true
  }

  network {
    name = "atest1"
  }

   provisioner "local-exec" {
     command = "echo ${format("MASTER_%02d", count.index)}=\"${self.network.0.fixed_ip_v4}\" >> ips.txt"
  }
   
}

resource "openstack_compute_floatingip_associate_v2" "dcos_master_ips" {
  count       = "${var.dcos_master_count}"
  floating_ip = "${element(openstack_networking_floatingip_v2.dcos_master_ips.*.address, count.index)}"
  instance_id = "${element(openstack_compute_instance_v2.dcos_master.*.id, count.index)}"

}

resource "openstack_networking_floatingip_v2" "dcos_agent_ips" {
  count = "${var.dcos_agent_count}"
  pool  = "hvfloating-894"
}

resource "openstack_compute_instance_v2" "dcos_agent" {
  name            = "${format("${var.dcos_cluster_name}-agent-%02d", count.index)}"
  depends_on      = ["openstack_compute_instance_v2.dcos_bootstrap"]
  count           = "${var.dcos_agent_count}"
  flavor_id       = "${var.openstack_flavor_id}"
  key_pair        = "terraform-key"
  security_groups = ["default"]

  block_device {
    uuid                  = "${var.openstack_image_id}"
    source_type           = "image"
    destination_type      = "volume"
    volume_size           = 20
    boot_index            = 0
    delete_on_termination = true
  }

  network {
    name = "atest1"
  }
}

resource "openstack_compute_floatingip_associate_v2" "dcos_agent_ips" {
  count       = "${var.dcos_agent_count}"
  floating_ip = "${element(openstack_networking_floatingip_v2.dcos_agent_ips.*.address, count.index)}"
  instance_id = "${element(openstack_compute_instance_v2.dcos_agent.*.id, count.index)}"


}

resource "openstack_networking_floatingip_v2" "dcos_public_agent_ips" {
  count = "${var.dcos_public_agent_count}"
  pool  = "hvfloating-894"
}

resource "openstack_compute_instance_v2" "dcos_public_agent" {
  name            = "${format("${var.dcos_cluster_name}-public-agent-%02d", count.index)}"
  depends_on      = ["openstack_compute_instance_v2.dcos_bootstrap"]
  count           = "${var.dcos_public_agent_count}"
  flavor_id       = "${var.openstack_flavor_id}"
  key_pair        = "terraform-key"
  security_groups = ["default"]

  block_device {
    uuid                  = "${var.openstack_image_id}"
    source_type           = "image"
    destination_type      = "volume"
    volume_size           = 20
    boot_index            = 0
    delete_on_termination = true
  }

  network {
    name = "atest1"
  }
}

resource "openstack_compute_floatingip_associate_v2" "dcos_public_agent_ips" {
  count       = "${var.dcos_public_agent_count}"
  floating_ip = "${element(openstack_networking_floatingip_v2.dcos_public_agent_ips.*.address, count.index)}"
  instance_id = "${element(openstack_compute_instance_v2.dcos_public_agent.*.id, count.index)}"

}



################## Null

resource "null_resource" "bootstrap" {

  depends_on      = ["openstack_compute_floatingip_associate_v2.dcos_public_agent_ips"]

  connection {
    user        = "core"
    private_key = "${file(var.dcos_ssh_key_path)}"
    host        = "${openstack_compute_floatingip_associate_v2.dcos_bootstrap_ip.floating_ip}"
  }

  #provisioner "local-exec" {
  #  command = "rm -rf ./do-install.sh"
  #}

  provisioner "local-exec" {
    command = "echo BOOTSTRAP=\"${openstack_compute_instance_v2.dcos_bootstrap.network.0.fixed_ip_v4}\" >> ips.txt"
  }

  provisioner "local-exec" {
    command = "echo CLUSTER_NAME=\"${var.dcos_cluster_name}\" >> ips.txt"
  }

  provisioner "local-exec" {
    command = "./make-files.sh"
  }

  provisioner "local-exec" {
    command = "sed -i -e '/^- *$/d' ./config.yaml"
  }

  provisioner "remote-exec" {
    inline = [
      "wget -q -O dcos_generate_config.sh -P $HOME ${var.dcos_installer_url}",
      "mkdir $HOME/genconf",
    ]
  }

  provisioner "file" {
    source      = "./ip-detect"
    destination = "$HOME/genconf/ip-detect"
  }

  provisioner "file" {
    source      = "./config.yaml"
    destination = "$HOME/genconf/config.yaml"
  }

  provisioner "remote-exec" {
    inline = ["sudo bash $HOME/dcos_generate_config.sh",
      "docker run -d -p 4040:80 -v $HOME/genconf/serve:/usr/share/nginx/html:ro nginx 2>/dev/null",
      "docker run -d -p 2181:2181 -p 2888:2888 -p 3888:3888 --name=dcos_int_zk jplock/zookeeper 2>/dev/null",
      "sudo systemctl stop update-engine",
    ]
  }
}

resource "null_resource" "master_bootstrap" {
    count       = "${var.dcos_master_count}"
    depends_on      = ["null_resource.bootstrap"]

    connection {
    user        = "core"
    private_key = "${file(var.dcos_ssh_key_path)}"
    host        = "${element(openstack_compute_floatingip_associate_v2.dcos_master_ips.*.floating_ip, count.index)}"
  }

  #provisioner "local-exec" {
  #  command = "rm -rf ./do-install.sh"
  #}

  provisioner "local-exec" {
    command = "while [ ! -f ./do-install.sh ]; do sleep 1; done"
  }

  provisioner "file" {
    source      = "./do-install.sh"
    destination = "/tmp/do-install.sh"
  }

  provisioner "remote-exec" {
    inline = [ "bash /tmp/do-install.sh master",
    "sudo systemctl stop update-engine",
    ]
  }
}

resource "null_resource" "agent_bootstrap" {
   depends_on      = ["null_resource.master_bootstrap"]

    connection {
    user        = "core"
    private_key = "${file(var.dcos_ssh_key_path)}"
    host        = "${openstack_compute_floatingip_associate_v2.dcos_agent_ips.floating_ip}"

  }
    provisioner "local-exec" {
    command = "while [ ! -f ./do-install.sh ]; do sleep 1; done"
  }

  provisioner "file" {
    source      = "do-install.sh"
    destination = "/tmp/do-install.sh"
  }

  provisioner "remote-exec" {
    inline = [ "bash /tmp/do-install.sh slave",
    "sudo systemctl stop update-engine",
    ]
  }
}

resource "null_resource" "public_agent_bootstrap" {
    depends_on      = ["null_resource.master_bootstrap"]

    connection {
    user        = "core"
    private_key = "${file(var.dcos_ssh_key_path)}"
    host        = "${openstack_compute_floatingip_associate_v2.dcos_public_agent_ips.floating_ip}"
  }

  provisioner "local-exec" {
    command = "while [ ! -f ./do-install.sh ]; do sleep 1; done"
  }

  provisioner "file" {
    source      = "do-install.sh"
    destination = "/tmp/do-install.sh"
  }

  provisioner "remote-exec" {
    inline = [ "bash /tmp/do-install.sh slave_public",
    "sudo systemctl stop update-engine",
    ]
  }
}

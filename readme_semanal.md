# Ejercicio Semanal

## ¡Importante!

Ten mucho cuidado con los valores sensibles que puedas exponer en tus soluciones. Recuerda que otras personas pueden ver la información de tus entregables y, por lo tanto, acceder a este tipo de información. ¡Siempre trata de mantener la seguridad de tus datos y de los datos de tus clientes!

Prepara un `.gitignore` en tu repositorio para evitar subir archivos innecesarios o con información sensible. Puedes guiarte por la [Documentación de HashiCorp](https://developer.hashicorp.com/terraform/language/style#gitignore).

Recuerda terminar cada prueba que realices con un `terraform destroy` para evitar costes innecesarios. **¡No lo olvides!**

### ¡¡¡OBLIGATORIO!!!

Está terminantemente **PROHIBIDO** introducir secretos (como el del Service Principal) en texto plano. Cuando hablamos de texto plano, nos referimos a cualquier archivo que no esté cifrado.

Este tipo de información puede ser utilizada por personas malintencionadas para acceder a tus recursos en la nube y realizar acciones no autorizadas.

Si necesitas introducir algún tipo de secreto, haz uso de los secretos de GitHub.

Este tipo de prácticas son las que se esperan en un entorno profesional y es importante que las adquieras desde el principio, puesto que, además de los riesgos de seguridad que conllevan para la empresa, también pueden suponer un despido directo por mala praxis.

## Información Previa al Desarrollo del Ejercicio

- Se entregará un nuevo Service Principal de Microsoft Azure para el desarrollo de este ejercicio. Su nombre será de la forma `spnl3-<alias_email>-1`. Se pueden encontrar sus credenciales en el keyvault que se ha estado utilizando hasta el momento.
- El módulo desarrollado deberá ser alojado en el repositorio donde se entregaron los ejercicios de la formación. Alójalo en `/soluciones/modulo-weekly-exercise/`.
- Se entregará un nuevo repositorio de GitHub sobre el que se habrá de desarrollar el workflow de GitHub Actions. Aquí es donde se debe alojar el "*ejemplo de uso*" que se mencionará en el enunciado.

## Enunciado

Se desea desarrollar en terraform un módulo que permita desplegar el siguiente workload:

- Múltiples instancias de máquinas virtuales especificadas a través de un mapa de objetos. Cada una de estas máquinas puede tener diferentes atributos.
- Un balanceador de carga que distribuya el tráfico entre las instancias de máquinas virtuales.
- El resto de elementos de red necesarios para completar la configuración de red de la solución.

El módulo debe ser alojado en un repositorio de GitHub y debe contener un README.md con la documentación necesaria para su uso.

Adicionalmente se debe crear un segundo repositorio de GitHub que disponga de un workflow de GitHub Actions que cumpla con los siguientes requisitos:

- Se debe ejecutar un plan de terraform cada vez que se realice un pull request a la rama principal del repositorio. 
- [**OPCIONAL**]El resultado del plan debe ser publicado como comentario en el pull request.
- Se debe ejecutar un apply de terraform cada vez que se realice un merge a la rama principal del repositorio(Pull request closed).
- [**OPCIONAL**]Se debe disponer de la opción de ejecutar plan/apply/destroy de terraform de forma manual para poder ejecutarlo en cualquier momento en caso de necesidad.

Un ejemplo de uso del módulo desarrollado debe ser incluido en el repositorio de GitHub que contiene el workflow de GitHub Actions y debe ser desplegado en Azure utilizando para ello el Service Principal de Microsoft Azure que se le haya facilitado.


Para comenzar con la realizacion del ejercicio voy a mostrar la estructura de directorios y archivos 

vamos a diferenciarlos en dos partes, contenido de terraform y el contenido de github actions.

## Terraform:

└── modulo-weekly-exercise
    ├── examples
    │   └── examples.tf
    ├── main.tf
    ├── outputs.tf
    ├── readme.md
    └── variables.tf


## Github Actions:

workflows/
├── README.md
├── plan-pr.yaml
├── apply-main.yaml
└── manual-exec.yaml


Ademas vamos a necesitar un par de requisitos previos:

-Clave publica de SSH: la podemos generar con el siguiente comando

```bash
ssh-keygen -t rsa -b 4096 -C brjagasanchez@gmail.com

```

en este caso la he asignado a mi correo personal

luego la podemos ver y copiar con el siguiente comando:

```bash
cat ~/.ssh/id_rsa.pub
```

esta clave la vamos a implementar para la creacion de las maquinas virtuales


EL otro requisito, es tener definidas las variables;
ARM_CLIENT_ID	ID del cliente del SP
ARM_CLIENT_SECRET	Secreto del SP
ARM_SUBSCRIPTION_ID	ID de suscripción de Azure
ARM_TENANT_ID	ID del tenant de Azure

en el repositorio de github en el que vamos a implementar las actions deberemos establecer dichas variables como secretos.

Dicho y hechos estos requisitos, podemos comenzar con el codigo de los archivos.

## Contenido de Terraform:

Como en muchos ejercicios comenzaremos creando el archivo main.tf, en este caso, definiremos en este archivo;

- El grupo de recursos que vamos a utilizar

- Una red virtual

- Una subnet 

- Interfaz de internet de azure, la cual contendra las ips

- Una maquina virtual, con sus interfaces de red, la key ssh previamente generada, el espacio y configuracion de disco, la imagen a utilizar

- Creacion de una ip publica para el balanceador de carga y el propio balanceador en si

Especificado el contenido, asi quedaria el codigo:

## main.tf

```bash
#creamos la red virtual
resource "azurerm_virtual_network" "main" {
  name                = "${var.prefix}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = var.resource_group_name
}
#creamos las subnets
resource "azurerm_subnet" "main" {
  name                 = "${var.prefix}-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}
#aqui empieza a cambiar el formato al que estamos acostumbrados, ya que tendremos que configurar interfaces
resource "azurerm_network_interface" "nics" {
  for_each = var.vms

  name                = "${each.key}-nic"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Dynamic"
  }
}
# esta es la configuacion para la creacion de la maquina virtual
resource "azurerm_linux_virtual_machine" "vms" {
  for_each = var.vms

  name                = each.key
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = each.value.size
  admin_username      = each.value.username

  network_interface_ids = [
    azurerm_network_interface.nics[each.key].id,
  ]
#tenemos que implementar ssh
  admin_ssh_key {
    username   = each.value.username
    public_key = each.value.ssh_key
  }

#configuracion del disco
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
#especificacion de la imagen
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }
}
#configuracion del balanceador de carga
resource "azurerm_lb" "main" {
  name                = "${var.prefix}-lb"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Basic"
  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.lb.id
  }
}

resource "azurerm_public_ip" "lb" {
  name                = "${var.prefix}-public-ip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Basic"
}

```

realizado el archivo main, lo siguiente es establecer todas las variables en un archivo, en este tendremos que definir las variables del main y sus atributos, que luego recibiran datos del archivo de ejemplos


el archivo de variables quedaria de la siguiente manera:ç


## variables.tf

```bash
#variable para definir el grupo de recursos
variable "resource_group_name" {
  type        = string
  description = "Nombre del resource group"
}
#ubicación de los recursos
variable "location" {
  type        = string
  default     = "westeurope"
  description = "Ubicación de los recursos"
}
#prefijo para los nombres de recursos
variable "prefix" {
  type        = string
  description = "Prefijo para los nombres de recursos"
}
#mapeo de la máquina virtual
variable "vms" {
  type = map(object({
    size     = string
    username = string
    ssh_key  = string
  }))
  description = "Mapa de máquinas virtuales"
}


```

como complementario al ejercicio vamos a realizar un archivo de outputs en el que simplemente recibiremos una salida de las ips de la maquina virtual, quedando de la siguiente manera:


## output.tf

```bash
output "public_ip" {
  value = azurerm_public_ip.lb.ip_address
}

```


para terminar con la parte de terraform tendremos que asignar valores a las variables mediante el archivo example.tf el cual quedaria de la siguiente manera:

## examples/example.tf

```bash

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}

resource "azurerm_resource_group" "main" {
  name     = "rg-bgarcia-dvfinlab"
  location = "West Europe"
}

}
module "vms_lb" {
  source              = "../"
  resource_group_name = "rg-bgarcia-dvfinlab"
  location            = "westeurope"
  prefix              = "ejemplo"

  vms = {
    vm1 = {
      size     = "Standard_B1ls"
      username = "azureuser"
      ssh_key  = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDbp8Slk3pa5Df8hxTCboA06F1lVYBnwEePRS/mAazawvd9fKYgoxz+1rrDc5tVwja1mQ1trY+LYqOoTdmYrwp00jOGe/nEwlUpUMsCh/rG1eRYGWZ75keCrZrWPlY2SABZcBhoYdWGkeKhbkwR1Dh5KU6eIavX3i0SZNg2+tbjlRnfOc1IGBT8/7UCjkjUsP0YIwykRd333XAQ1X58DSpeXb08EU9CPrKrrmSMFQgNUi3VeR9K+/EMOlhmYAc8cHAD1HMNf2qz7yFUNsd4fDEMz5WLaA7pGIB4lFz+YINtJBaEIOJ+HkuSMJGh1KlTEZlVrCZT9fn6TKpN4O1krf6TexoVyhWp0zfgr4UjqA3fEsjCTAOnP+/oMZdKSmyTcqOk8AmcNnubTn3M62euCr9IV3zKykuGD2ZNHMVlZ2TLanXHNP7z2YLr92924ebZeGrmJe9XgsGHaM0fjaRg7nujA2NvD2VrC8JdppBBY97WM1dUhMBiSpsWmjt+vvOQNJ9nemM+JN/kQ9I1pE5rDZxWY7e0BQbN8qpVnFOx7LlcizCCwc2xq76S3nLXck+54R/cuUUyAnnpmMCq5Vma3Ydnt0fogbaBDAREjozThZ5ASC0ZeXqnO3IUFGrba7gtR3eTBsjb0X9xj80wqhhvT8k2t6Blusg8na30ZFDU/UJCHw== brjagasanchez@gmail.com" 
    },
    vm2 = {
      size     = "Standard_B1ls"
      username = "azureuser"
      ssh_key  = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDbp8Slk3pa5Df8hxTCboA06F1lVYBnwEePRS/mAazawvd9fKYgoxz+1rrDc5tVwja1mQ1trY+LYqOoTdmYrwp00jOGe/nEwlUpUMsCh/rG1eRYGWZ75keCrZrWPlY2SABZcBhoYdWGkeKhbkwR1Dh5KU6eIavX3i0SZNg2+tbjlRnfOc1IGBT8/7UCjkjUsP0YIwykRd333XAQ1X58DSpeXb08EU9CPrKrrmSMFQgNUi3VeR9K+/EMOlhmYAc8cHAD1HMNf2qz7yFUNsd4fDEMz5WLaA7pGIB4lFz+YINtJBaEIOJ+HkuSMJGh1KlTEZlVrCZT9fn6TKpN4O1krf6TexoVyhWp0zfgr4UjqA3fEsjCTAOnP+/oMZdKSmyTcqOk8AmcNnubTn3M62euCr9IV3zKykuGD2ZNHMVlZ2TLanXHNP7z2YLr92924ebZeGrmJe9XgsGHaM0fjaRg7nujA2NvD2VrC8JdppBBY97WM1dUhMBiSpsWmjt+vvOQNJ9nemM+JN/kQ9I1pE5rDZxWY7e0BQbN8qpVnFOx7LlcizCCwc2xq76S3nLXck+54R/cuUUyAnnpmMCq5Vma3Ydnt0fogbaBDAREjozThZ5ASC0ZeXqnO3IUFGrba7gtR3eTBsjb0X9xj80wqhhvT8k2t6Blusg8na30ZFDU/UJCHw== brjagasanchez@gmail.com" 
    }
  }
}

```

una vez realizado haremos el init en la carpeta examples:

init correcto: 
![alt text](../soluciones/img/image1.png)

como detalle al no haber un main.tf en la carpeta example, tendremos que añadir en el archivo example.tf la cabecera para el provider:

```bash
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}

}

```

ahora realizaremos el plan y el apply:

el plan es correcto: 

![alt text](../soluciones/img/image2.png)

ahora hacemos el apply:

vemos que esta todo correcto: 

![alt text](../soluciones/img/image3.png)

ahora si vamos a la cloud de azure vemos que esta todo correctamente creado:
![alt text](../soluciones/image/image5.png)

si nos metemos por ejemplo a una maquina virtual veremos sus datos:


![alt text](../soluciones/image/image6.png)



Una vez realizados todos los archivos de terraform pasamos al contenido de Github.Actions


## Github Actions.


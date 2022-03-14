# RobinFoodTest

### **Prueba Tecnica para la Robin Food**

Este repositorio tiene como objetivo presentar de manera detallada la solucion de una prueba tecnica para la startup ***robin food***.

En el primer punto se solicita *Construir una infraestructura basica para AWS o Azure utilizando herramientas como CloudFormation o Terraform que se pueden utilizar de forma repetitiva*

## 1. INFRASTRUCTURE

**1.1 Preparacion inicial**

En primer lugar, esta prueba se realizara en una maquina virtual con sistema operativo linux ubuntu 20.04.

Despues se procede a la instalacion de la herramienta *Visual Studio Code* mediante el comando ***sudo snap install --classic code*** para trabajar de forma mas organizada.

Luego, se realiza la instalacion de git mediante el comando ***sudo apt install -y git***, se crea el repositorio remoto en [github](https://github.com/andres1397/RobinFoodTest). Se realizan las configuraciones iniciales con ***git config --global user.name "git user"*** y ***git config --global user.email "git email"*** y se realiza el *push* inicial para realizar la conexion entre el repositorio local y el remoto.

Posteriormente se seleeciona la herramienta ***Terraform*** para la implementacion de **infraestructura como codigo**. Se realiza la instalacion siguiendo la documentacion en el sitio oficial de [Terraform](https://www.terraform.io/downloads).

Finalmente, se selecciona **AWS** como cloud provider para la implementacion. Para facilitar el uso de credenciales en las pruebas de la infraestructura se realiza la instalacion de ***AWS_CLI*** siguiendo la documentacion oficial de [AWS](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) y la configuracion basica en la que se indica la region de implementacion y las credenciales mediante el comando *aws configure*.

**1.2 Contexto**

Para la implementacion de esta infraestructura se utilizara una aplicacion existente en un repositorio publico.

Se trata de una aplicacion sencilla que muestra reseñas e informacion de diferentes peliculas. La aplicacion esta separada en dos repositorios de github donde se puede visualizar el [Frontend](https://github.com/juan-ruiz/movie-analyst-ui) y el [Backend](https://github.com/juan-ruiz/movie-analyst-api) de la aplicacion.

Se implementara principalmente el funcionamiento de la aplicacion, dotandola de la infraestructura necesaria para ello pasando por buenas practicas de arquitectura.

**1.3 Implementacion de infraestructura**

En esta seccion se explicara el proceso de construccion del documento ***main.tf*** ubicado en ***1_infrastructure/instances***, junto con los problemas encontrados, las soluciones alternas y las mejores practicas de cada caso. En esta construccion solo se usaran **recursos** (**resources**) para la definicion de componentes. 

**1.3.1 Networking**

Despues de indicar el cloud provider y la region de uso se procede a crear la **VPC** (**V**irtual **P**rivate **C**loud), lo cual se define como un segmento privado de la nube de **AWS** para la creacion de nuestros recursos y que esten seguros. Nuestra **VPC** tendra como direccion de red ***192.168.0.0/16***.

Dentro de nuestra ***VPC*** crearemos dos subredes publicas para nuestra instancia web, ambas con el nombre *Public_Subnet* y terminan con **A** y **B** respectivamente. Lo primero que haremos es indicar que pertenece a la *VPC* que creamos anteriormente con la linea ***vpc_id***. Posteriormente indicaremos la *zona de disponibilidad* siendo la ***A*** para la primera y la ***B*** para la segunda. El siguiente paso es indicar las direcciones de red, teniendo las direcciones *192.168.10.0/24* en caso de la subred A y *192.168.20.0/24* para la subred B. Finalmente, llamamos el parametro **map_public_ip_on_launch** y le pasamos el valor ***true*** con la finalidad de que las instancias creadas en estas subredes obtengan una ip publica de forma predeterminada, esto nos servira para que sean publicamente accesibles.

Por otra parte, crearemos otra subred en la zona de dispoibilidad **C** para crear nuestra instancia que contrenda el *Backend* de la aplicacion. Replicaremos los pasos anteriores con excepcion de la configuracion de la ip publica, puesto que al ser el *Backend* de la aplicacion tener en cuenta algunos parametros de seguridad.

Ahora se crearan las salidas a internet, para la instancia *web* se creara un ***Internet Gateway*** y para la instancia *api* un ***NAT Gateway*** con el motivo de no exponer nuestro *Backend* en internet, pero para que nuestro *NAT Gateway* sea publico necesitamos una ***EIP*** **E**lastic **IP**, la cual es una ip publica fija.

Posteriormente crearemos las tablas de ruteo (*direccionamiento*) para el trafico de nuestras instancias. Crearemos dos tablas, ambas apuntando a internet (***0.0.0.0/0***) con la diferencia de que la publica se expondra mediante el *Internet Gateway* y la privada mediante el *NAT Gateway* que creamos anteriormente. Finalmente, establecemos la tabla de ruteo publica como la tabla *principal* para que nuestra instancia no tenga problemas para salir a internet con el ***AutoScalingGroup*** y el ***Application Load Balancer*** que crearemos mas adelante para brindar *alta disponibilidad* y *resiliencia*.

**1.3.2 Security**

En el apartado de seguridad plantearemos la idea de implementar en el firewall de la *VPC* el ingreso de peticiones solamente **HTTP** y **HTTPS** como buena practica, pero como la complejidad de esta arquitectura no es muy alta, no es necesario. En caso de tener una arquitectura mas compleja se puede implementar la observacion anterior o incluso utilizar el servicio ***AWS WAF*** el cual es el servicio de *Firewall* que ayuda a proteger las arquitecturas de multiples tipos de ataques.

La siguiente configuracion sera la de los **grupos de seguridad**, los cuales pueden verse como *firewalls* a nivel de instancia.

Las buenas practicas indican que los security groups solo deben permitir ingreso por puertos especificos para evitar exponer las instancias completamente a internet. Sin embargo, hubo un problema con el cual las maquinas no se aprovisionaban ni permitia acceder a ellas, por lo que se expondran a internet mediante cualquier puerto.

Por el momento se creara solo un grupo de seguridad, para verificar la funcionalidad del servicio pero posteriormente se creara uno para el *balanceador de cargas*.

La instancia ***API*** se encuentra protegida gracias al *NAT Gateway*, por su parte, protegeremos la instancia ***WEB*** con ayuda el balanceador de cargas que crearemos posteriormente.

**1.3.3 Compute**

Como se ha mencionado anteriormente, vamos a crear dos instancias ***WEB*** y ***API***. Para estas instancias usaremos la capa gratuita, usaremos una imagen *ubuntu* y el tipo de instancia sera **t2.micro**. Definimos la direccion ip privada en ambas instancias, la direccion privada de la instancia *WEB* pero la direccion ip privada de la instancia ***API*** es importante para el funcionamiento de la aplicacion, en este caso es ***192.168.30.10***.

Posteriormente, se indica la clave ssh que se utilizara para conexiones remotas, se establece el grupo de seguridad y se indica la subred en la que se desplegara la instancia.

Finalmente, se establece el ***user-data*** que es la configuracion inicial que tendran las instancias. En este caso usaremos un script para cada instancia, estos scripts se encuentran en este repositorio en la carpeta de nombre ***scripts/***. Ambos realizan la instalacion de *git* para clonar el repositorio, *nodejs* porque la aplicacion esta escrita en este lenguaje y lo necesitamos para inicializar la misma y *npm* para instalar las dependencias necesarias de la aplicacion. Estos scripts se diferencian en el repositorio que van a clonar y en la creacion de una variable de entorno que, en el caso de la instancia *WEB*, la variable de entorno es la ip privada de la instancia *API* para la comunicacion entre estas.

Al final de la definicion de la instancia *API* se define un ***depends_on*** debido a que necesitamos que primero se este corriendo el *Backend* de la aplicacion para no tener problemas con el *Frontend*.

**1.3.4 Resilience & High Availability**

Para continuar con las buenas practicas, se implementara un ***Auto Scaling Group*** y un ***Application Load Balancer***. Esta implementacion solo se realizara en la instancia *WEB* y se justificara en posteriores secciones.

Primero, se crea la configuracion de lanzamiento (**launch configuration**) donde se definira la *ami*, el *tipo de instancia* el *user-data* y definiremos el *security group*. Como se menciono anteriormente, crearemos nuevos *security groups* para brindar mayor seguridad.

Luego, creamos los nuevos *security groups*, seran 2. El primero se encargara de exponer el *el balanceador de cargas* a internet, recibiendo peticiones **HTTP** solamente. Mientras que el segundo se encargara de recibir esas peticiones filtradas por el *balanceador* a nuestra instancia creada por *auto scaling group*

Posteriormente, definiremos nuestro ***Auto Scaling Group*** donde  indicaremos la capacidad minima, maxima y deseada, indicamos la plantilla de configuracion y establecemos las subredes en las que aplicara nuestro *Auto Scaling Group*

Despues, definimos el ***Balanceador de Cargas***, establecemos el tipo de balanceador, en este caso sera de **Aplicacion**, indicamos el *security group* que definimos en esta seccion y finalmente establecemos las subredes en las que actuara nuestro *balanceador*

Establecemos el *listener* (escuchador) para indicar que recibiremos las peticiones **HTTP** y las enviaremos al *target group* (grupo destino) en donde estaran nuestras instancias creadas por el *Auto Scaling Group*.

Finalmente definimos la relacion entre el ***Application Load Balancer*** y el ***Auto Scaling Group***.

Con esto completamos nuestra arquitectura, ahora vendra un punto extra sobre la aplicacion y algunas consideraciones.

**1.3.5 RDS MySQL Instance**

Dentro de la aplicacion parece que se quiere implementar una base de datos MySQL, sin embargo estas lineas se encuentran comentadas. Dentro de este archivo terraform se define una base de datos *mysql* con su respectiva *subnet* y *security group*. Sin embargo, estas lineas se dejan comentadas ya que no se puede probrar la implementacion.

**1.3.6 Conclusion**

Dentro de esta prueba tecnica se realiza el montaje de una arquitectura sencilla para validar conociminetos generales de *AWS*, *IaC* y *Configuration Managment*. En este archivo se deja la explicacion de cada implementacion realizada. Tambien me gustaria dejar algunas de apreciaciones:

1. Se puede mejorar la ***Excelencia Operacional*** de esta arquitectura implementando almacenamiento *EBS* para la persistencia de los datos, sin embargo no se implemento porque no se esta realizando ningun cambio.

2. En esta arquitectura se define el *NAT Gateway* para mejorar la seguridad de la instancia *API* pero se debe tener cuidado con la facturacion de este componente. Recomiendo implementarlo cuando sea debidamente necesario.

3. Para la aplicacion, en caso de implementar una base de datos, se podria utilizar *Aurora* en lugar de *MySQL* para aprovechar el servicio totalmente administrado de *AWS*

4. La arquitectura presentada tiene opciones de mejora, por ejemplo tomar la ip privada de la instancia *API* mediante el *aws cli* y realizar un *remote-exec* para pasarsela como variable de entorno y no depender de una ip fija. Pero pienso que no es necesario en el caso de esta prueba. Sin embargo, de ser necesario puede implementarse sin mayor problema.

5. Como se menciono al inicio de este documento, la aplicacion es tomada de un repositorio publico. Se respeta la propiedad intelectual del autor del repositorio.
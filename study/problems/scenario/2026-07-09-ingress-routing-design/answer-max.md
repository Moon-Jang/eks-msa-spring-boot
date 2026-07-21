1-1: 서비스 갯수와 상관없이 controller는 1개만 있어도 된다.  하나의 controller 가 여러 ingress 규칙을 모두 참조하기 때문이다. 

1-2: /order, /payment 는 같은 도메인으로 들어온 트래픽을 path를 보고 각각의 서비스로 라우팅해주는 방식. admin.shop.com 은 도메인 기반으로 라우팅해주는 방식.


2: 서비스마다 LB를 두는건 비용이 서비스가 늘어날때마다 같이 늘어나는구조, 그리고 LB 마다 인증서, 모니터링을 따로 관리해야됨 따라서 하나의 컨트롤러와 하나의 LB를 사용하는 구조 선택.

강의 범위 밖: host 규칙으로 나누는건 라우팅이지 접근제어가 아님.  ip 제어 방법도 있겠지만 사내 계정 인증을 확인하는 어플리케이션을 pod 로 하나 띄워서 ingress controller 가 트래픽을 서비스로 보내기 전에 무조건 거치게 만들어서 제어하는 방법이 있을것 같음.


3: 후보 A - 컨트롤러가 트래픽을 넘겨줄 대상을 찾지 못함. kubectl describe ingress <ingress name></ingress>ingress-name -n namespace, kubectl get svc -n namespace 명령어로 backend와 서비스의 이름과 포트가 잘 매칭되어있는지 확인한다.

후보 B - kubectl describe svc 서비스이름, kubectl describe pod 파드이름 명령어를 사용해서
pod에 설정된 label 값과 describe svc 의 selector 값을 비교 대조해본다.


후보 C - 간헐적으로 503이 뜬다면 pod가 어떠한 이슈로 계속 죽어서 트래픽을 받지 못해서 생길수 있다고 생각함.

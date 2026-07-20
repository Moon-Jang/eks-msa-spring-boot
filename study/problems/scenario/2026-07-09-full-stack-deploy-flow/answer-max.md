1번: dev, prod 로 namespace를 분리. kubectl create namespace dev, kubectl create namespace prod. 

강의 범위 밖:namespace가 달라도 pod 끼리는 통신이 가능하기 때문에 완전한 격리가 필요하다면 별도 클러스터를 만들어야한다.


2-1: 만약 트래픽이 늘어 pod가 1개에서 3개로 늘어난다고 가정했을때 디비도 3개가된다. 독립적인 디비가 3개가 된다. 요청이 어느 pod로 가냐에 따라 각각 다른 데이터를 읽고 쓰게 된다. 정합성 박살남. 

2-2: localhost:5432 -> service-name:5432 deployment 스펙에 정의된 pod 복제본의 레이블명과 서비스의 selector 이름과 매칭시켜야 서비스로 요청이 들어왔을때 서비스의 selector 이름과 매칭된 pod로 요청이 보내짐.

강의 범위 밖: 관리형 RDS를 사용해서 쿠버네티스 밖에 디비를 두면 pod의 생명주기와 상관없이 데이터는 안전하다.


3번: Deployment 요소를 이용해 새 pod를 생성하고 기존 pod를 순차적으로 종료시킨다.

강의 범위 밖: 모름


4-1: Ingress Controller -> Service

4-2: 사용자 -> Route53 -> AWS LB -> Ingress Controller -> Service -> Pod:8080

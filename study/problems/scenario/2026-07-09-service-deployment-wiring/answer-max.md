1-1: 서비스의 selector 이름이 deployment의 replicas template에서 pod에 지정해주는 라벨 이름과 같아야한다. 즉 deployment의 spec.selector.matchLabels.app, spec.template.metadata.labels.app값들과 service 의 spec.selector.app 이름이 같아야한다. deployment의 spec의 replicas 는 서비스에 연결될 pod 를 관리해주는것이므로 pod를 생성할때 부여해줄 label 값을 결국 service의 selector와 같게 해줘야함.

1-2: 신버전의 pod 가 Running 상태더라도 어플리케이션이 정상적으로 동작중인지는 알수 없기 때문에. pod는 정상 작동중이지만 안에서 스프링앱이 준비되지 않았을 수 있다.

강의 범위 밖: 잘모름.


2-1: http://payment-service.payment.svc.cluster.local:포트, 만약 order 네임스페이스안에 payment-service 라는 서비스가 있다면 그쪽으로 연결이되어버리기 때문에 큰 문제가 발생할 수 있음. 그리고 짧은 이름은 같은 네임스페이스 안에서 편의성을 제공하는 기능정도라고 생각하면 좋음. 


2-2: 서비스의 port 는 80, targetPort는 8080, targetPort는 스프링이 리슨하는 포트로 무조건 맞춰야함. port는 자유롭게 설정해도 무방.


3-1: 라운드 로빈이 도는 시점은 요청할때 마다가 아니고 새로운 TCP 커넥션을 열때다. 그런데 스프링은 성능을 위해 커넥션을 캐싱함 (keep-alive로 재사용). 그렇기 때문에 pod 한쪽에 쏠릴수있다.

강의 범위 밖: 잘모름.

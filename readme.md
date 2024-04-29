# SED: (Socio-economic || Social-ecological) diversity
## Parameters as distributions
## Resource use scenarios
![base model parameters](/graphics/ModelFigure.png)
I am writing ![base model parameters](/graphics/w.png){:height="30px" width="30px"}
## Governance

U=int(u\bar * y>w\tilde ? 1 : 0)
S=int(u\bar * 1-y>w\tilde ? 1 : 0)


```mermaid
graph TD;
    A-->B;
    A-->C;
    B-->D;
    C-->D;
```

```mermaid
flowchart TD;
subgraph "External"
    A(gender) --"0.2 x gender"--> B("w x 0.3e + 1");
    F(health) --> B;
    end
    
    B -- Yes --> C[OK];
    C --> D[Rethink];
    D --> B;
    B -- No ----> E[End];
```

```mermaid
flowchart TB
    c1("a node")-->a2
    subgraph one
    a1("<img src='https://iconscout.com/ms-icon-310x310.png'; width='30' />")-->a2
    end
    subgraph two
    b1-->b2
    end
    subgraph three
    c1-->c2
    a2 -->b1
    end
    one --> two
    three --> two
    two --> c2
```

```mermaid
flowchart TB
    subgraph External
    a1("<img src='https://iconscout.com/ms-icon-310x310.png'; width='30' />")
    a2("<img src='https://cdn.iconscout.com/icon/free/png-512/free-developer-tool-1889493-1597553.png'; width='30' />")
    a3("<img src='https://cdn.iconscout.com/icon/free/png-512/free-logo-1889509-1597569.png'; width='30' />")
    end
    subgraph Variables
    w("w \n 0.3")
    q
    e
    p
    a
    end
    subgraph Key relations
 w_tilde("<img src='https://zahachtah.github.io/CAS/images/w_tilde_combined.png';width='30'/>")
 u_bar("<img src='https://zahachtah.github.io/CAS/images/u_bar_combined.png';width='30'/>")
 \alpha("<img src='https://zahachtah.github.io/CAS/images/alpha.png';width=90 height=60/>")
 u_bar

    end
    a1-- "0.2"--> w
    a2-->w
    a--> \alpha
    w-->w_tilde
    q-->w_tilde

```


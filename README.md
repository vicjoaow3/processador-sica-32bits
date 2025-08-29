# Processador de 32 bits - Trabalho da Disciplina BCC720

Este repositório contém a implementação de um processador de 32 bits em Verilog, desenvolvido como parte da disciplina BCC720[cite: 101]. O projeto abrange desde a especificação do conjunto de instruções (ISA) e o design do datapath até a implementação e simulação funcional do processador[cite: 111, 113].

## Arquitetura

O processador foi projetado com as seguintes características:

* **Tipo**: Processador de 32 bits com uma arquitetura Load-Store, onde as operações aritméticas e lógicas ocorrem exclusivamente entre registradores.
* **Implementação**: Design multi-ciclo implementado como uma Máquina de Estados Finitos (FSM) que controla o fluxo de execução das instruções.
* **Banco de Registradores**: Contém 32 registradores de propósito geral, cada um com 32 bits. Todos os registradores são inicializados com o valor zero.
* **ULA (Unidade Lógica e Aritmética)**: Suporta as operações de adição, subtração, AND, OR, NOT, multiplicação e divisão[cite: 279]. Gera as flags `N` (negativo) e `Z` (zero) com base no resultado[cite: 145, 279].
* **Interface de Memória**: A comunicação com a memória é feita através de uma interface dedicada com os sinais `MAR` (endereço), `MBR_in` (dado lido), `MBR_out` (dado a ser escrito), `mem_enable` e `mem_op` (operação de leitura/escrita)[cite: 133, 150].
* **Entrada e Saída (E/S)**: O processador possui pinos de `input_data` e `output_data` para interagir com o ambiente externo, controlados pelas instruções `LoadExt` e `StoreExt`[cite: 151, 369].

## Estrutura dos Arquivos

O projeto está organizado nos seguintes arquivos Verilog:

* `processador.v`: Módulo top-level que instancia e conecta a unidade de controle e o datapath[cite: 359, 360].
* `datapath.v`: Contém os componentes do caminho de dados, como o PC, o banco de registradores e a ULA[cite: 366, 367].
* `unidade_controle.v`: Implementa a Máquina de Estados Finitos (FSM) que decodifica as instruções e gera os sinais de controle[cite: 370, 371].
* `ula.v`: Implementa as operações lógicas e aritméticas[cite: 374].
* `banco_registradores.v`: Define o banco de 32 registradores de 32 bits[cite: 376].
* `memoria.v`: Módulo de memória RAM síncrona.
* `tb_top.v`: Testbench completo para a verificação do processador. Ele instancia a CPU e a memória, carrega o programa de teste e verifica os resultados finais[cite: 382, 383].
* `program.hex`: Arquivo contendo o código de máquina do programa de teste que é carregado na memória para a simulação[cite: 387].

## Como Simular

Para compilar e executar a simulação, é necessário um simulador Verilog como o Icarus Verilog.

1.  **Compilação:**
    Compile todos os módulos Verilog usando o seguinte comando no terminal (assumindo que todos os arquivos `.v` estejam presentes):
    ```bash
    iverilog -o cpu32.out *.v
    ```

2.  **Execução:**
    Execute o arquivo compilado com o VVP:
    ```bash
    vvp cpu32.out
    ```

O testbench (`tb_top.v`) foi projetado para ser autoverificável. Ele executará dois cenários de teste, um com `input_data = 10` e outro com `input_data = 20`[cite: 117, 390]. Ao final, ele imprimirá os valores dos registradores Reg0 a Reg5, as posições de memória 1 e 2, e o valor de `output_data` para cada cenário[cite: 396]. Se todos os testes passarem, uma mensagem de sucesso será exibida, conforme a Figura 1 do relatório[cite: 456].

Além disso, a simulação gera um arquivo `wave.vcd` que pode ser aberto em um visualizador de formas de onda (como o GTKWave) para uma análise detalhada dos sinais[cite: 409].

## Conjunto de Instruções (ISA)

O processador implementa o seguinte conjunto de instruções, conforme definido na Tabela 6 do relatório[cite: 261, 262]:

| Instrução  | Formato | Opcode   | Funct    | Observações                                     |
| :--------- | :------ | :------- | :------- | :---------------------------------------------- |
| `Add`      | R       | `0x00`   | `0x20`   | `rd = rs + rt`                                  |
| `Sub`      | R       | `0x00`   | `0x22`   | `rd = rs - rt`                                  |
| `And`      | R       | `0x00`   | `0x24`   | `rd = rs & rt`                                  |
| `Or`       | R       | `0x00`   | `0x25`   | `rd = rs | rt`                                  |
| `Not`      | R       | `0x00`   | `0x2F`   | Unário: `rd = ~rs`                              |
| `Mul`      | R       | `0x00`   | `0x18`   | Resultado truncado para 32 bits                 |
| `Div`      | R       | `0x00`   | `0x1A`   | Divisão inteira                                 |
| `JE`       | I       | `0x04`   | -        | Desvio se `Z=1`                                 |
| `JNE`      | I       | `0x05`   | -        | Desvio se `Z=0`                                 |
| `JG`       | I       | `0x06`   | -        | Desvio se `N=0` e `Z=0`                         |
| `JGE`      | I       | `0x07`   | -        | Desvio se `N=0`                                 |
| `JL`       | I       | `0x1E`   | -        | Desvio se `N=1`                                 |
| `JLE`      | I       | `0x1F`   | -        | Desvio se `N=1` ou `Z=1`                        |
| `JMP`      | J       | `0x02`   | -        | Salto incondicional PC-relativo                 |
| `Load`     | I       | `0x23`   | -        | `rt = Mem[rs + imm]`                            |
| `Store`    | I       | `0x2B`   | -        | `Mem[rs + imm] = rt`                            |
| `LoadCteH` | I       | `0x0F`   | -        | Carrega imediato nos bits 31:16 de `rt`         |
| `LoadCteL` | I       | `0x0D`   | -        | Carrega imediato nos bits 15:0 de `rt`          |
| `LoadExt`  | I       | `0x20`   | -        | `rt = input_data`                               |
| `StoreExt` | I       | `0x2A`   | -        | `output_data = rt`                              |
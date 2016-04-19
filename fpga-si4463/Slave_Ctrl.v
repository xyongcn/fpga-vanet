module Slave_Ctrl(
	clk,
	
	//��CPU�Ľӿ�
	mosi,
	miso,
	sclk,
	//signal_int,
	
	//��SRAM�Ľӿ�
	SRAM_read,
	SRAM_write,
	SRAM_hint,
	Data_to_sram,
	Data_from_sram,
	SRAM_full,
	SRAM_empty,
	SRAM_count,
	
	//֡�����ж�,��wireless_ctrl����
	frame_recved_int,
	
	//��CPU���ӵ��ж�
	cpu_recv_int,
	
	Spi_Current_State_1,
	Spi_rrdy,
	Spi_trdy,
	Data_from_spi
	
	
);
output Data_from_spi;
output Spi_trdy;
output Spi_rrdy;
input	clk;
input frame_recved_int;
output reg cpu_recv_int;
output reg  [7:0] Spi_Current_State_1=0;	
//assign Spi_Current_State_1={3'b000,Spi_Current_State};
	//��CPU�Ľӿ�
input	mosi;
output	miso;
input	sclk;
//output	signal_int;
	
	//��SRAM�Ľӿ�
output reg	SRAM_read;
output reg  SRAM_write;
input	SRAM_hint;
output reg [15:0]	Data_to_sram;
input[15:0]	Data_from_sram;
reg[15:0] Data_from_sram_reg;
input	SRAM_full;
input	SRAM_empty;
input[10:0]	SRAM_count;

//��spi������
wire slave_reset_n;
assign slave_reset_n=0;
wire slave_ss_n;
assign slave_ss_n=0;

wire slave_irq;
reg[7:0] slave_data_to_spi;
wire[7:0] slave_data_from_spi;
reg[7:0] slave_data_from_spi_reg;
reg slave_write;

	spi_slave slave(
	.RESET_in(slave_reset_n),
    .CLK_in(clk),
    .SPI_CLK(sclk),
    .SPI_SS(slave_ss_n),
    .SPI_MOSI(mosi),
    .SPI_MISO(miso),
    .SPI_DONE(slave_irq),
    .DataToTx(slave_data_to_spi),
    .DataToTxLoad(slave_write),
    .DataRxd(slave_data_from_spi)
    //.index1		: out natural range 0 to 7
    );

///////����SPI�������������ѡ��ѭ����������
//Ϊ�˸��õ���Ӧ�ԣ�������������Ƶģ�����Ƶ�ģʽ
/*
	CPU���������� cmd::0x66+data_len+����
	CPU���������� cmd::0x77+data_len ���������Ҫ�ȴ�һ��ʱ��
				  ���أ�SRAM�е�������
	��ȡSRAM���ֽ����� //���Ҳ���Բ���Ҫ�����ǵȵ�SRAM�����ݵ���һ��ֵ����һ�������İ��󣬸�CPU�ж�
				  ����һ�ַ�ʽ�Ǵ�SRAM��ȡ�����ݣ��ȵ�ȡ��֮�󣬸�CPU����һ����־��0xFFFF���ܿ�����Ҫ�����ֽ�
				  



*/
reg[4:0] Spi_Current_State=0;
reg[7:0] Data_len=0;
reg[7:0] Sended_count=0;
reg Byte_flag=0;
//reg tx_flag=0;
//reg rx_flag=0;

always@(posedge clk)
begin
	Spi_Current_State_1[7]=Spi_rrdy;
	case (Spi_Current_State)
		0:
		begin
			if(slave_irq)
			begin
				Spi_Current_State_1[6:0]=1;
				slave_data_from_spi_reg=slave_data_from_spi;
				Spi_Current_State=3;
			end
		end
		3:
		begin
			case(slave_data_from_spi_reg)
				8'b01100110: //CPU��������
				begin
					Data_to_sram[15:8]=slave_data_from_spi_reg;  //��������ͳ��ȣ�����Wireless_Ctrl��������
					Sended_count=0;
					Byte_flag=0;
					//tx_flag=1;
					Spi_Current_State=4;
				end
				/*
				8'h01110111: //CPU��������
				begin
					//rx_flag=1;
					Spi_Current_State=16; 
				end*/
				default:
				begin
					Spi_Current_State_1[6:0]=0;
					Spi_Current_State=0;
				end
			endcase
		end
		4:
		begin
			if(slave_irq)
			begin
				Spi_Current_State_1[6:0]=Spi_Current_State_1[6:0]+1;
				slave_data_from_spi_reg=slave_data_from_spi;
				Spi_Current_State=6;
			end
		end
		6:
		begin
			Data_len=slave_data_from_spi_reg;
			Data_to_sram[7:0]=slave_data_from_spi_reg+8'h02;
			Spi_Current_State=7;
		end
		//����������ݳ���д��SRAM
		7:
		begin
			if(!SRAM_full)
			begin
				//Spi_Current_State_1[6:0]=0;
				SRAM_write=1;
				Spi_Current_State=8;
			end
		end
		8:
		begin
			if(SRAM_hint)
			begin
				//Spi_Current_State_1=Spi_Current_State_1+1;
				SRAM_write=0;
				Spi_Current_State=9;
			end
		end
		//�����ݳ���д��SRAM
		9:
		begin
			if(!SRAM_full)
			begin
				Data_to_sram={8'h00,Data_len[7:0]};
				SRAM_write=1;
				Spi_Current_State=10;
			end
		end
		10:
		begin
			if(SRAM_hint)
			begin
				//Spi_Current_State_1=Spi_Current_State_1+1;
				SRAM_write=0;
				Spi_Current_State=11;
			end
		end
		//��SPI��ȡ���ݲ�д��SRAM
		11:
		begin
			if(slave_irq)
			begin
				Spi_Current_State_1[6:0]=Spi_Current_State_1[6:0]+1;
				slave_data_from_spi_reg=slave_data_from_spi;
				Spi_Current_State=13;
			end
		end
		13:
		begin
			if(!Byte_flag)
			begin
				Data_to_sram[15:8]=slave_data_from_spi_reg;
				Byte_flag=~Byte_flag;
				Sended_count=Sended_count+1'b1;
				Spi_Current_State=11;
				if(Sended_count>=Data_len)
				begin
					Data_to_sram[7:0]=8'b000;
					Byte_flag=~Byte_flag;
					Spi_Current_State=14;
				end
			end
			else
			begin
				Data_to_sram[7:0]=slave_data_from_spi_reg;
				Byte_flag=~Byte_flag;
				Sended_count=Sended_count+1'b1;
				Spi_Current_State=14;
			end
		end
		
		14:
		begin
			if(!SRAM_full)
			begin
				SRAM_write=1;
				Spi_Current_State=15;
			end
		end
		15:
		begin
			if(SRAM_hint)
			begin
				
				SRAM_write=0;
				if(Sended_count<Data_len)
				begin
					Spi_Current_State=11;
				end
				else
				begin
					Spi_Current_State_1[6:0]=0;
					Spi_Current_State=0;
				end
			end
		end
		
		
		/*
		////////������CPU��������/////////////////
		///��SRAM��ȡ������
		16:
		begin
			if(!SRAM_empty)
			begin
				SRAM_read=1;
				Spi_Current_State=17;
			end
		end

		17:
		begin
			if(SRAM_hint)
			begin
				SRAM_read=0;
				Data_from_sram_reg=Data_from_sram;
				Data_len=Data_from_sram_reg[15:8];
				if(Spi_trdy)
				begin
					Spi_write_n=0;
					Spi_mem_addr=3'b001;
					Data_to_spi={8'h00,Data_len};
					Sended_count=0;
					Spi_Current_State=18;
					Byte_flag=0;
				end
			end
		end
		18:
		begin
			Spi_write_n=1;
			Spi_Current_State=19;
		end
		19:
		begin
			Spi_Current_State=20;
		end
		//���͵�һ������
		20:
		begin
			if(Spi_trdy)
			begin
				Data_to_spi={8'h00,Data_from_sram_reg[7:0]};

				Spi_Current_State=21;
				Spi_write_n=0;
				Spi_mem_addr=3'b001;
			end
		end
		21:
		begin
			Spi_write_n=1;
			Spi_Current_State=22;
		end
		22:
		begin
			Sended_count=Sended_count+1'b1;
			Spi_Current_State=23;
		end
		//ȡ�����ݲ���ʼ����
		23:
		begin
			if(Sended_count<Data_len)
			begin
				if(!SRAM_empty)
				begin
					SRAM_read=1;
					Spi_Current_State=24;
				end
			end
			else
			begin
				Spi_Current_State=0;
			end
		end
		24:
		begin
			if(SRAM_hint)
			begin
				Data_from_sram_reg=Data_from_sram;
				Spi_Current_State=25;
			end
		end
		25:
		begin
			Data_to_spi={8'h00,Data_from_sram_reg[15:8]};
			Spi_write_n=0;
			Spi_mem_addr=3'b001;
			Spi_Current_State=26;
		end
		26:
		begin
			Spi_write_n=1;
			Spi_Current_State=27;
		end
		27:
		begin
			Sended_count=Sended_count+1'b1;
			if(Sended_count<Data_len)
			begin
				Spi_Current_State=28;
			end
			else
				Spi_Current_State=0;
		end
		28:
		begin
			Data_to_spi={8'h00,Data_from_sram_reg[7:0]};
			Spi_write_n=0;
			Spi_mem_addr=3'b001;
			Spi_Current_State=29;
		end
		29:
		begin
			Spi_write_n=1;
			Spi_Current_State=30;
		end
		30:
		begin
			Spi_Current_State=23;
		end*/
		default:
		begin
			Spi_Current_State=0;
		end
	endcase

end

/////��ʱ����///////////////
reg delay_start=0;
reg[31:0] delay_count=0;
reg[7:0] delay_mtime=0;
reg delay_int=0;

always@(posedge clk)
begin
	if(!delay_start)
	begin
		delay_count<=0;
		delay_int<=0;
	end
	else
	begin
		delay_count<=delay_count+1'b1;
		if(delay_count==delay_mtime*20000)
			delay_int<=1;
	end
end

////�жϺ���//////
reg[2:0] Int_Current_State=0;

always@(posedge clk)
begin
	case (Int_Current_State)
		0:
		begin
			if(frame_recved_int)
			begin
				Int_Current_State=1;
			end
		end
		1:
		begin
			cpu_recv_int=1;
			delay_start=1;
			delay_mtime=1;
			Int_Current_State=2;
		end
		2:
		begin
			if(delay_int)
			begin
				delay_start=0;
				cpu_recv_int=0;
				Int_Current_State=3;
			end
		end
		3:
		begin
			Int_Current_State=0;
		end
		default:
		begin
			cpu_recv_int=0;
			Int_Current_State=0;
		end
	endcase
end

endmodule
import os
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

SMTP_SERVER = os.getenv("SMTP_SERVER", "smtp.gmail.com")
try:
    SMTP_PORT = int(os.getenv("SMTP_PORT", "587"))
except ValueError:
    SMTP_PORT = 587

SMTP_USERNAME = os.getenv("SMTP_USERNAME", "")
SMTP_PASSWORD = os.getenv("SMTP_PASSWORD", "")
SMTP_SENDER = os.getenv("SMTP_SENDER", "Go with Mobilis <no-reply@gowithmobilis.com>")

# Se o username estiver configurado mas o SENDER for padrão, usamos o username como remetente
if SMTP_USERNAME and SMTP_SENDER == "Go with Mobilis <no-reply@gowithmobilis.com>":
    SMTP_SENDER = f"Go with Mobilis <{SMTP_USERNAME}>"

def send_verification_email(email: str, token: str):
    # O link de verificação aponta para o domínio do Render (onde o backend corre)
    # A rota GET /verify-email tratará de confirmar a conta e retornar a página de sucesso.
    backend_url = "https://go-with-mobilis-backend.onrender.com"
    verification_link = f"{backend_url}/verify-email?token={token}"

    print(f"\n======================================================================")
    print(f"[EMAIL SERVICE] A PROCESSAR VERIFICAÇÃO PARA: {email}")
    print(f"[EMAIL SERVICE] LINK DE VERIFICAÇÃO: {verification_link}")
    print(f"======================================================================\n")

    # Se as credenciais não estiverem configuradas, operamos em modo simulação (fallback)
    if not SMTP_USERNAME or not SMTP_PASSWORD:
        print("[EMAIL SERVICE] [AVISO] Credenciais SMTP não configuradas no Render.")
        print("[EMAIL SERVICE] [SIMULAÇÃO] O link acima foi impresso nos logs para ativação manual.")
        return

    # Construção do e-mail HTML Premium
    msg = MIMEMultipart('alternative')
    msg['Subject'] = "Confirme o seu endereço de e-mail - Go with Mobilis"
    msg['From'] = SMTP_SENDER
    msg['To'] = email

    html_content = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=initial-scale=1.0">
        <title>Confirme o seu E-mail</title>
        <style>
            body {{
                font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif;
                background-color: #F1F5F9;
                margin: 0;
                padding: 0;
                -webkit-font-smoothing: antialiased;
            }}
            .container {{
                max-width: 600px;
                margin: 40px auto;
                background-color: #FFFFFF;
                border-radius: 16px;
                overflow: hidden;
                box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.05), 0 4px 6px -4px rgba(0, 0, 0, 0.05);
            }}
            .header {{
                background: linear-gradient(135deg, #0054A6 0%, #003C78 100%);
                padding: 40px 20px;
                text-align: center;
            }}
            .header h1 {{
                color: #FFFFFF;
                margin: 0;
                font-size: 28px;
                font-weight: 700;
                letter-spacing: -0.5px;
            }}
            .content {{
                padding: 40px 30px;
                color: #334155;
                line-height: 1.6;
            }}
            .content p {{
                font-size: 16px;
                margin-top: 0;
                margin-bottom: 24px;
            }}
            .button-container {{
                text-align: center;
                margin: 35px 0;
            }}
            .button {{
                background-color: #8CC63F;
                color: #FFFFFF !important;
                text-decoration: none;
                padding: 16px 36px;
                font-size: 16px;
                font-weight: 600;
                border-radius: 30px;
                display: inline-block;
                box-shadow: 0 4px 6px -1px rgba(140, 198, 63, 0.3), 0 2px 4px -1px rgba(140, 198, 63, 0.2);
                transition: all 0.2s ease-in-out;
            }}
            .footer {{
                background-color: #F8FAFC;
                padding: 24px 30px;
                text-align: center;
                border-top: 1px solid #E2E8F0;
                font-size: 12px;
                color: #64748B;
            }}
            .footer a {{
                color: #0054A6;
                text-decoration: none;
            }}
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>Go with Mobilis</h1>
            </div>
            <div class="content">
                <p>Olá,</p>
                <p>Agradecemos o seu registo na plataforma <strong>Go with Mobilis</strong>! Para começar a explorar as paragens, rotas e alertas da rede Mobilis em tempo real, precisamos apenas de confirmar que este endereço de e-mail é seu.</p>
                
                <div class="button-container">
                    <a href="{verification_link}" class="button" target="_blank">Confirmar o meu E-mail</a>
                </div>

                <p>Se o botão acima não funcionar, copie e cole o seguinte endereço no seu navegador:</p>
                <p style="word-break: break-all; font-size: 14px; color: #0054A6; background-color: #F8FAFC; padding: 12px; border-radius: 8px; border: 1px solid #E2E8F0;">
                    {verification_link}
                </p>
                
                <p>Se não efetuou este registo, pode ignorar este e-mail com segurança.</p>
                <p>Com os melhores cumprimentos,<br>A Equipa Go with Mobilis</p>
            </div>
            <div class="footer">
                <p>&copy; 2026 Go with Mobilis. Desenvolvido para mobilidade urbana inteligente.</p>
                <p>Se tiver dúvidas, contacte o nosso suporte.</p>
            </div>
        </div>
    </body>
    </html>
    """

    msg.attach(MIMEText(html_content, 'html'))

    try:
        server = smtplib.SMTP(SMTP_SERVER, SMTP_PORT)
        server.starttls()
        server.login(SMTP_USERNAME, SMTP_PASSWORD)
        server.sendmail(SMTP_SENDER, email, msg.as_string())
        server.close()
        print(f"[EMAIL SERVICE] E-mail de confirmação enviado com sucesso para: {email}")
    except Exception as e:
        print(f"[EMAIL SERVICE] [ERRO] Falha ao enviar e-mail via SMTP: {e}")
        print(f"[EMAIL SERVICE] [FALLBACK] Certifique-se de que as credenciais nos logs estão ativas para testes.")

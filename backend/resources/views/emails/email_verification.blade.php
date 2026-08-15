<!DOCTYPE html>
<html lang="id">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Verifikasi Email Anda</title>
</head>
<body style="margin:0; padding:0; background-color:#eef0f7; font-family: Arial, Helvetica, sans-serif;">
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#eef0f7; padding:30px 0;">
        <tr>
            <td align="center">
                <table role="presentation" width="600" cellpadding="0" cellspacing="0" style="background-color:#ffffff; border-radius:10px; overflow:hidden; box-shadow:0 4px 18px rgba(30,27,75,0.12);">

                    <!-- HEADER -->
                    <tr>
                        <td style="background:linear-gradient(135deg, #1E3A8A 0%, #6D28D9 100%); background-color:#312E81; padding:32px 30px; text-align:center;">
                            <h1 style="margin:0; color:#ffffff; font-size:22px; letter-spacing:0.5px; font-weight:700;">
                                KREAVANA
                            </h1>
                            <p style="margin:6px 0 0; color:#DDD6FE; font-size:13px; letter-spacing:1px; text-transform:uppercase;">
                                Verifikasi Email Anda
                            </p>
                        </td>
                    </tr>

                    <!-- BODY -->
                    <tr>
                        <td style="padding:36px 40px 10px;">
                            <p style="margin:0 0 16px; color:#1F2937; font-size:15px;">Halo,</p>
                            <p style="margin:0 0 16px; color:#374151; font-size:15px; line-height:1.7;">
                                Terima kasih telah mendaftar di <strong style="color:#312E81;">Kreavana</strong>. Untuk menyelesaikan pendaftaran, silakan masukkan kode verifikasi berikut:
                            </p>
                        </td>
                    </tr>

                    <!-- OTP BOX -->
                    <tr>
                        <td style="padding:0 40px;">
                            <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
                                <tr>
                                    <td style="background-color:#F5F3FF; border:1px solid #C4B5FD; border-radius:8px; padding:18px; text-align:center;">
                                        <span style="font-size:32px; font-weight:700; letter-spacing:8px; color:#1E3A8A;">
                                            {{ $otp }}
                                        </span>
                                    </td>
                                </tr>
                            </table>
                        </td>
                    </tr>

                    <!-- EXPIRY INFO -->
                    <tr>
                        <td style="padding:16px 40px 0; text-align:center;">
                            <p style="margin:0; font-size:13px; color:#6B7280;">
                                Kode ini berlaku selama <strong>15 menit</strong>.
                            </p>
                        </td>
                    </tr>

                    <!-- WARNING -->
                    <tr>
                        <td style="padding:24px 40px 0;">
                            <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
                                <tr>
                                    <td style="border-left:4px solid #6D28D9; background-color:#F5F3FF; padding:14px 18px; border-radius:0 6px 6px 0;">
                                        <p style="margin:0; font-size:14px; color:#4C1D95; line-height:1.6;">
                                            <strong>Penting:</strong> Jangan bagikan kode verifikasi ini kepada siapa pun. Tim Kreavana tidak pernah meminta kode verifikasi Anda.
                                        </p>
                                    </td>
                                </tr>
                            </table>
                        </td>
                    </tr>

                    <!-- CLOSING -->
                    <tr>
                        <td style="padding:28px 40px 36px;">
                            <p style="margin:0 0 4px; color:#374151; font-size:15px;">Salam hangat,</p>
                            <p style="margin:0; color:#1F2937; font-size:15px; font-weight:700;">Tim Kreavana</p>
                        </td>
                    </tr>

                    <!-- FOOTER -->
                    <tr>
                        <td style="background-color:#1E1B4B; padding:20px 40px; text-align:center;">
                            <p style="margin:0; color:#A5B4FC; font-size:12px;">
                                Email ini dikirim secara otomatis, mohon tidak membalas email ini.
                            </p>
                            <p style="margin:6px 0 0; color:#6366F1; font-size:12px;">
                                &copy; {{ date('Y') }} Kreavana. All rights reserved.
                            </p>
                        </td>
                    </tr>

                </table>
            </td>
        </tr>
    </table>
</body>
</html>

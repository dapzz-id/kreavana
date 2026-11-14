<?php

namespace App\Console\Commands;

use Illuminate\Foundation\Console\ServeCommand as BaseServeCommand;
use Symfony\Component\Console\Attribute\AsCommand;

#[AsCommand(name: 'serve', description: 'Serve the application on the PHP development server (default port 8001)')]
class ServeCommand extends BaseServeCommand
{
    /**
     * Get the port for the command.
     *
     * @return int
     */
    protected function port()
    {
        $port = $this->input->getOption('port');

        if (is_null($port)) {
            [, $port] = $this->getHostAndPort();
        }

        $port = $port ?: (int) env('SERVER_PORT', 8001);

        return $port + $this->portOffset;
    }
}

